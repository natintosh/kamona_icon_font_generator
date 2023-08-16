enum NamingStrategy {
  snake,
  camel;

  static NamingStrategy? fromString(String? namingStrategy) {
    switch (namingStrategy) {
      case 'snake':
        return NamingStrategy.snake;
      case 'camel':
        return NamingStrategy.camel;
      case null:
        return null;
      default:
        throw Exception('Invalid naming strategy.');
    }
  }
}
