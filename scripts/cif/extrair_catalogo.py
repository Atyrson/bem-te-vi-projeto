"""Inventário OOXML determinístico; não executa fórmulas nem importa respostas."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import posixpath
import re
import xml.etree.ElementTree as ET
import zipfile

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
CODE = re.compile(r'^[bsde](?:\d{1}|\d{3,5})?$')
REF = re.compile(r'(?<![A-Za-z0-9_])\$?([A-Z]{1,3})\$?(\d+)(?::\$?([A-Z]{1,3})\$?(\d+))?')


def column_number(s):
    n = 0
    for c in s:
        n = n * 26 + ord(c) - 64
    return n


def column_name(n):
    s = ''
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def translate(formula, origin, target):
    a, b = re.fullmatch(r'([A-Z]+)(\d+)', origin).groups()
    c, d = re.fullmatch(r'([A-Z]+)(\d+)', target).groups()
    def shift(m):
        col, row = m.groups()
        return (col if col.startswith('$') else column_name(column_number(col) + column_number(c) - column_number(a))) + (row if row.startswith('$') else str(int(row) + int(d) - int(b)))
    return re.sub(r'(\$?[A-Z]{1,3})(\$?\d+)', shift, formula)


def references(formula):
    refs = []
    for a, b, c, d in REF.findall(formula):
        for col in range(column_number(a), column_number(c or a) + 1):
            for row in range(int(b), int(d or b) + 1):
                refs.append(f'{column_name(col)}{row}')
    return refs


def read_book(path):
    with zipfile.ZipFile(path) as z:
        strings = []
        if 'xl/sharedStrings.xml' in z.namelist():
            strings = [''.join(t.text or '' for t in si.findall('.//m:t', NS)) for si in ET.fromstring(z.read('xl/sharedStrings.xml'))]
        style_root = ET.fromstring(z.read('xl/styles.xml'))
        fonts = style_root.find('m:fonts', NS)
        fills = style_root.find('m:fills', NS)
        styles = []
        for xf in style_root.find('m:cellXfs', NS):
            font = fonts[int(xf.get('fontId', 0))]
            bold = font.find('m:b', NS)
            fill = fills[int(xf.get('fillId', 0))]
            color = fill.find('m:patternFill/m:fgColor', NS)
            styles.append({'bold': bold is not None and bold.get('val', '1') != '0', 'fill': dict(color.attrib) if color is not None else {}})
        rels = {r.get('Id'): r.get('Target') for r in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
        sheets = []
        for sheet in ET.fromstring(z.read('xl/workbook.xml')).find('m:sheets', NS):
            target = rels[sheet.get(f'{{{REL}}}id')]
            root = ET.fromstring(z.read(posixpath.normpath('xl/' + target) if not target.startswith('/') else target.lstrip('/')))
            cells, shared = {}, {}
            for c in root.findall('m:sheetData/m:row/m:c', NS):
                addr = c.get('r'); v = c.find('m:v', NS); f = c.find('m:f', NS)
                value = v.text if v is not None else None
                if c.get('t') == 's':
                    value = strings[int(value)]
                elif c.get('t') == 'inlineStr':
                    value = ''.join(t.text or '' for t in c.findall('.//m:t', NS))
                formula = None
                if f is not None:
                    formula = f.text
                    if f.get('t') == 'shared' and formula:
                        shared[f.get('si')] = (addr, formula)
                cells[addr] = {'text': value if c.get('t') in ('s', 'inlineStr') else None, 'formula': formula, 'style': styles[int(c.get('s', 0))], '_shared': f.get('si') if f is not None and f.get('t') == 'shared' else None}
            for addr, cell in cells.items():
                if cell['_shared'] is not None and cell['formula'] is None:
                    origin, formula = shared[cell['_shared']]
                    cell['formula'] = translate(formula, origin, addr)
                del cell['_shared']
            sheets.append({'name': sheet.get('name'), 'state': sheet.get('state', 'visible'), 'cells': cells, 'validations': [ET.tostring(v, encoding='unicode') for v in root.findall('m:dataValidations/m:dataValidation', NS)]})
        return sheets


def extract(qualification, summary):
    books = [read_book(qualification), read_book(summary)]
    catalog = {'schema_version': 1, 'catalog_version': '0.1.0-inventory', 'rules_status': 'pending_review', 'sources': [{'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in (qualification, summary)], 'areas': []}
    audit = {'sheets': [], 'formula_findings': []}
    for bi, book in enumerate(books):
        for sheet in book:
            cells = sheet['cells']
            formulas = {a: c['formula'] for a, c in cells.items() if c['formula'] is not None}
            audit['sheets'].append({'source': bi, 'name': sheet['name'], 'state': sheet['state'], 'texts': {a: c['text'] for a, c in cells.items() if c['text']}, 'formulas': formulas, 'validations': sheet['validations']})
            for addr, formula in formulas.items():
                refs = references(formula)
                duplicates = [r for r, count in Counter(refs).items() if count > 1]
                if duplicates or '#REF!' in formula or addr in refs:
                    audit['formula_findings'].append({'source': bi, 'sheet': sheet['name'], 'cell': addr, 'formula': formula, 'repeated_references': duplicates, 'self_reference': addr in refs, 'broken_reference': '#REF!' in formula})
                # Numeric constants are deliberately not retained. Blank/input refs cannot be distinguished here.
    for sheet, prefix, pairs in zip(books[0][:4], 'bsde', [[('D', 'E'), ('F', 'G'), ('H', 'I')], [('D', 'E'), ('G', 'H')], [('D', 'E')], [('D', 'E')]]):
        cells = sheet['cells']; nodes = []
        for addr, cell in cells.items():
            col = re.sub(r'\d', '', addr); row = re.sub(r'\D', '', addr)
            text = (cell['text'] or '').strip().lower()
            if col != 'D' or not CODE.fullmatch(text) or not text.startswith(prefix):
                continue
            a = cells.get('A' + row, {}).get('text') or ''
            b = cells.get('B' + row, {}).get('text') or ''
            description = b.strip() or re.sub(r'\s*\([bsde]\d+\)\s*$', '', a).strip() or sheet['name']
            fields = []
            for codecol, valcol in pairs:
                codecell = cells.get(codecol + row, {})
                rawcode = (codecell.get('text') or '').strip().lower()
                if not CODE.fullmatch(rawcode):
                    continue
                valuecell = cells.get(valcol + row, {})
                fields.append({'code_cell': codecol + row, 'source_code': rawcode, 'value_cell': valcol + row, 'kind_observed': 'calculated' if valuecell.get('formula') is not None else 'input_candidate', 'formula': valuecell.get('formula'), 'code_style': codecell.get('style'), 'value_style': valuecell.get('style'), 'required': None})
            nodes.append({'code': text, 'description': description, 'source_row': int(row), 'label_style': cells.get('A' + row, {}).get('style'), 'fields': fields})
        # Alternate male aggregates have no adjacent code in these two rows.
        for code, address in ({'b6': 'I384'} if prefix == 'b' else {'s630': 'G183'} if prefix == 's' else {}).items():
            matches = [n for n in nodes if n['code'] == code]
            if matches:
                matches[0]['fields'].append({'code_cell': None, 'source_code': code, 'value_cell': address, 'kind_observed': 'calculated', 'formula': cells[address]['formula'], 'code_style': None, 'value_style': cells[address]['style'], 'required': None, 'mapping_status': 'proposed_male_variant'})
        codes = {n['code'] for n in nodes}
        for node in nodes:
            code = node['code']; parents = [c for c in codes if c != code and code.startswith(c)]
            node['parent_by_code'] = max(parents, key=len) if parents else None
            node['chapter'] = code[:2] if len(code) >= 2 else None
        by_cell = {f['value_cell']: n for n in nodes for f in n['fields']}
        for node in nodes:
            node['id'] = f"{prefix}:{node['source_row']}"
            for field in node['fields']:
                if field['formula']:
                    refs = references(field['formula'])
                    field['references'] = refs
                    children = [n for n in nodes if n['parent_by_code'] == node['code']]
                    omitted = [n['code'] for n in children if not any(f['value_cell'] in refs for f in n['fields'])]
                    unexpected = [r for r in refs if r not in by_cell or by_cell[r]['parent_by_code'] != node['code']]
                    if omitted or unexpected:
                        audit['formula_findings'].append({'source': 0, 'sheet': sheet['name'], 'cell': field['value_cell'], 'code': node['code'], 'omitted_prefix_children': omitted, 'references_outside_prefix_children': unexpected})
        audit.setdefault('duplicate_codes', []).extend({'sheet': sheet['name'], 'code': code, 'rows': [n['source_row'] for n in nodes if n['code'] == code]} for code, count in Counter(n['code'] for n in nodes).items() if count > 1)
        catalog['areas'].append({'code': prefix, 'name': sheet['name'], 'nodes': nodes})
    return catalog, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('qualification', type=Path)
    parser.add_argument('summary', type=Path)
    parser.add_argument('--output', type=Path, default=Path('catalogos/cif'))
    args = parser.parse_args()
    catalog, audit = extract(args.qualification, args.summary)
    args.output.mkdir(parents=True, exist_ok=True)
    for name, data in [('catalogo.v0.1.json', catalog), ('auditoria.v0.1.json', audit)]:
        (args.output / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
