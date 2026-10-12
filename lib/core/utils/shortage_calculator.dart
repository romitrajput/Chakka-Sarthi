class ShortageCalculator {
  static double calculate(double loadingWeight, double unloadingWeight) {
    final shortage = loadingWeight - unloadingWeight;
    return shortage < 0 ? 0.0 : double.parse(shortage.toStringAsFixed(2));
  }
}
