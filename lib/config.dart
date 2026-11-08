/// App configuration.
///
/// Get a free API key at https://opendata.transport.nsw.gov.au
/// (create an application and add the "Trip Planner APIs" and
/// "Public Transport - Realtime Vehicle Positions" (v1 + v2) products).
///
/// Run with:  flutter run --dart-define=TFNSW_API_KEY=your_key_here
class AppConfig {
  static const apiKey = String.fromEnvironment('TFNSW_API_KEY');

  static const baseUrl = 'https://api.transport.nsw.gov.au';

  /// How often the live data refreshes.
  static const tripRefresh = Duration(seconds: 30);
  static const vehicleRefresh = Duration(seconds: 15);
}
