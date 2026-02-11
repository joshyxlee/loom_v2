class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isLimited,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final String category;
  final bool isLimited;
}
