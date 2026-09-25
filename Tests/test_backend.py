import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    "pantry_backend", pathlib.Path(__file__).resolve().parents[1] / "Backend" / "server.py"
)
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class BackendTests(unittest.TestCase):
    def test_pack_sizes(self):
        self.assertEqual(backend.size("1.5 kg"), (1500, "grams"))
        self.assertEqual(backend.size("500 ml"), (500, "millilitres"))
        self.assertEqual(backend.size("6 pieces"), (6, "pieces"))
        self.assertIsNone(backend.size("family pack"))

    def test_translated_demo_search_is_review_required(self):
        found = backend.products_for("aloo", "demo-home")
        self.assertEqual(found[0]["name"], "Potatoes")
        self.assertTrue(found[0]["requiresNameApproval"])
        self.assertEqual(backend.products_for("unknown herb", "demo-home"), [])

    def test_live_result_uses_closest_name_and_real_variant_ids(self):
        old_mode, old_call = backend.MODE, backend.mcp_call
        backend.MODE = "swiggy"
        backend.mcp_call = lambda name, args: {
            "products": [
                {"displayName": "Potato Chips", "inStock": True, "isAvail": True,
                 "variations": [{"spinId": "wrong", "skuId": "wrong-sku",
                                 "quantityDescription": "100 g", "displayName": "Potato Chips",
                                 "price": {"offerPrice": 20}, "isInStockAndAvailable": True}]},
                {"displayName": "Fresh Potatoes", "inStock": True, "isAvail": True,
                 "variations": [{"spinId": "real-spin", "skuId": "real-sku",
                                 "quantityDescription": "1 kg", "displayName": "Fresh Potatoes",
                                 "price": {"offerPrice": 45}, "isInStockAndAvailable": True}]},
            ]
        }
        try:
            found = backend.products_for("aloo", "address-from-provider")
            self.assertEqual(found[0]["id"], "real-spin")
            self.assertEqual(found[0]["amount"], 1000)
            self.assertTrue(found[0]["requiresNameApproval"])
        finally:
            backend.MODE, backend.mcp_call = old_mode, old_call


if __name__ == "__main__":
    unittest.main()
