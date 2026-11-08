# NSW Transit (Flutter)

Trip planner for NSW buses, trains, metro and ferries, with live arrivals and live vehicle tracking.

## Features
- **Favourite places**: save Home, Work or anywhere else with a name and an icon. Drag to reorder, hold to rename or remove.
- **Search any address**: covers streets, suburbs, stops, stations, wharves and landmarks across NSW.
- **Fastest route first**: options are ranked by arrival time and tagged *Fastest*, *Fewest changes* and *Least walking*.
- **Live countdowns**: shows how long until your bus, train or ferry leaves, using real-time estimates with late, early or on-time badges. Refreshes every 30 s.
- **Live map**: shows where your actual vehicle is (refreshes every 15 s). Turn on **All nearby** to see every bus, train or ferry around your route.
- **Every stop along the way**: lists each stop with its time. Tap any stop to jump to it on the map.
- Change your start point, swap origin and destination, see your own location on the map, and use dark mode.

## Setup
1. **Get a free API key** at https://opendata.transport.nsw.gov.au. Create an application and add:
   - Trip Planner APIs
   - Public Transport – Realtime Vehicle Positions (v1)
   - Public Transport – Realtime Vehicle Positions v2
2. Install Flutter 3.27 or newer, then run:
   ```bash
   flutter pub get
   flutter run --dart-define=TFNSW_API_KEY=your_key_here
   ```

## Project layout
```
lib/
  main.dart                    app entry and shared services
  config.dart                  API key and refresh intervals
  models/place.dart            saved and searched places
  models/journey.dart          journeys, legs and stops parsed from the Trip Planner
  services/tfnsw_api.dart      stop_finder (search) and trip (routing and ranking)
  services/vehicle_service.dart  GTFS-realtime vehicle positions
  services/favourites_store.dart saved favourites and recent places (on device)
  services/location_service.dart GPS
  screens/home_screen.dart     search bar, favourites, recents
  screens/search_screen.dart   address and stop search
  screens/routes_screen.dart   trip options with countdowns
  screens/journey_screen.dart  live map and stop-by-stop timeline
  widgets/                     countdown, mode chips, NSW mode colours
assets/logo/                   app logo and launcher icon sources
tool/make_logo.py              draws the logo PNGs (needs Python + Pillow)
android/, ios/                 platform projects (location permissions already added)
```

## Logo
The logo is drawn by `tool/make_logo.py`. To change it, edit the script and run:
```bash
python tool/make_logo.py
dart run flutter_launcher_icons
```

## Notes
- Vehicles are matched to your trip using the `RealtimeTripId` from the Trip Planner. When an operator doesn't publish a matching ID, the app falls back to vehicles on the same route near your path.
- Map tiles come from the public OpenStreetMap tile server, which is fine for development. Before publishing, switch `urlTemplate` in `journey_screen.dart` to a tile provider you have an account with (MapTiler, Stadia, Thunderforest and so on), per OSM's tile usage policy.
- Don't ship your API key inside a public app build. For production, route the requests through a small backend proxy.
