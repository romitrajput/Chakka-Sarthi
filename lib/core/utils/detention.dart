/// Detention days = Unloading date − Reporting date (calendar days, Indian time).
/// Returns null when either date is missing, and never less than 0.
int? calculateDetentionDays(DateTime? reportingDate, DateTime? unloadingDate) {
  if (reportingDate == null || unloadingDate == null) return null;
  DateTime istDay(DateTime d) {
    final ist = d.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime.utc(ist.year, ist.month, ist.day);
  }
  final days = istDay(unloadingDate).difference(istDay(reportingDate)).inDays;
  return days < 0 ? 0 : days;
}
