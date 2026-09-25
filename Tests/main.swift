import Foundation

var basket = Basket()
let food = SampleCatalogue.products.filter { $0.store == .food }
let groceries = SampleCatalogue.products.filter { $0.store == .groceries }
basket.change(food[0], by: -1)
assert(basket.quantity(food[0]) == 0)
basket.change(food[0], by: 2)
basket.change(groceries[0], by: 3)
assert(basket.total(food) == 498)
assert(basket.total(groceries) == 96)
basket.clear(food)
assert(basket.total(food) == 0)
assert(basket.total(groceries) == 96)
basket.change(groceries[0], by: 100)
assert(basket.quantity(groceries[0]) == 20)
assert(Set(SampleCatalogue.products.map(\.id)).count == SampleCatalogue.products.count)
print("Basket checks passed: quantities, totals, limits and separate carts")

let list = GroceryMatcher.match("aloo 1 kg\npeyaj 500 g\ndim 6\natta 1 kg\nunknown herb 2 packs\nmilk")
assert(list.count == 6)
assert(list[0].product?.name == "Potatoes" && list[0].packs == 1 && list[0].issue == .confirmName)
assert(list[1].product?.name == "Onions" && list[1].packs == 1 && list[1].issue == .confirmQuantity)
assert(list[2].product?.name == "Eggs" && list[2].packs == 1 && list[2].issue == .confirmQuantity)
assert(list[3].product?.name == "Wheat flour" && list[3].packs == 1 && list[3].issue == .confirmQuantity)
assert(list[4].issue == .unavailable)
assert(list[5].issue == .missingQuantity)
let prefix = GroceryMatcher.match("2 kg aloo\n2 packets milk")
assert(prefix[0].request.amount == 2000 && prefix[0].packs == 2)
assert(prefix[1].request.amount == 2 && prefix[1].issue == .confirmQuantity)
assert(GroceryMatcher.match("tomato 1 kg")[0].packs == 2)
let typo = GroceryMatcher.match("potatos 1 kg")[0]
assert(typo.product?.name == "Potatoes" && typo.issue == .confirmName)
let bridged = try JSONDecoder().decode(GrocerySKU.self, from: Data("""
{"id":"live-1","name":"Potatoes","aliases":["aloo"],"amount":1000,"unit":"grams","packLabel":"1 kg","price":45,"symbol":"🥔","requiresNameApproval":true}
""".utf8))
assert(bridged.requiresNameApproval)
assert(GroceryMatcher.match("aloo 1 kg", catalogue: [bridged])[0].issue == .confirmName)
print("List checks passed: transliteration, pack size, missing and unmatched items")
