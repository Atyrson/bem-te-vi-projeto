import json
from pathlib import Path
import unittest
from extrair_catalogo import references, translate

ROOT = Path(__file__).resolve().parents[2]


class InventoryTest(unittest.TestCase):
    def test_shared_formula_translation(self):
        self.assertEqual(translate('SUM(C10:C17)+$A$1', 'C18', 'D18'), 'SUM(D10:D17)+$A$1')

    def test_reference_multiplicity_is_preserved(self):
        self.assertEqual(references('AVERAGE(E9:E11,E11)'), ['E9', 'E10', 'E11', 'E11'])

    def test_inventory_keeps_ambiguities_and_no_answers(self):
        catalog = json.loads((ROOT / 'catalogos/cif/catalogo.v0.1.json').read_text())
        nodes = [n for a in catalog['areas'] for n in a['nodes']]
        self.assertEqual(sum(len(n['code']) == 2 for n in nodes), 30)
        self.assertEqual(len({n['id'] for n in nodes}), len(nodes))
        self.assertEqual(sum(n['code'] == 's73020' for n in nodes), 2)
        for node in nodes:
            self.assertNotIn('answer', node)
            for field in node['fields']:
                self.assertIsNone(field['required'])
                self.assertNotIn('value', field)
        self.assertEqual(catalog['rules_status'], 'pending_review')


if __name__ == '__main__':
    unittest.main()
