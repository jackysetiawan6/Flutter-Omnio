import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class OmnioScreen extends StatefulWidget {
  const OmnioScreen({super.key, required this.onToggleTheme, required this.onLogout, required this.displayName});

  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final String displayName;

  @override
  State<OmnioScreen> createState() => _OmnioScreenState();
}

class _OmnioScreenState extends State<OmnioScreen> {
  int _selectedIndex = 0;
  final List<OmnioEvent> _events = [
    OmnioEvent('Family dinner', DateTime.now(), time: '19:00', type: 'Social', recurrence: 'Weekly', location: 'Home'),
    OmnioEvent('Plan tomorrow', DateTime.now(), time: '21:00', type: 'Planning'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _Dashboard(
        events: _events,
        onCalendar: () => setState(() => _selectedIndex = 1),
        onLocation: () => setState(() => _selectedIndex = 2),
      ),
      _CalendarPage(events: _events, onAdd: (date) => _addEvent(date)),
      const _LocationPage(),
      const _PlaceholderPage(title: 'Tasks', icon: Icons.check_circle_outline),
      const _PlaceholderPage(title: 'Notes', icon: Icons.sticky_note_2_outlined),
      const _ScraperPage(),
      _ProfilePage(displayName: widget.displayName, onLogout: widget.onLogout, onToggleTheme: widget.onToggleTheme),
    ];
    return Scaffold(
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: pages[_selectedIndex])),
      bottomNavigationBar: _OmnioDock(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
        onMore: () => _showMoreMenu(context),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Tasks'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 3); }),
            ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: const Text('Notes'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 4); }),
            ListTile(leading: const Icon(Icons.travel_explore), title: const Text('Price scout'), subtitle: const Text('Compare public web prices without AI'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 5); }),
            ListTile(leading: const Icon(Icons.person_outline), title: const Text('Profile & settings'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 6); }),
            ListTile(leading: const Icon(Icons.tune), title: const Text('Customize workspace'), subtitle: const Text('More modules can live here as Omnio grows'), onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }

  Future<void> _addEvent([DateTime? date]) async {
    final result = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddEventSheet(date: date ?? DateTime.now()),
    );
    if (result is _EventDraft && result.title.isNotEmpty) {
      setState(() => _events.add(OmnioEvent(result.title, result.date, time: result.time, type: result.type, location: result.location, recurrence: result.recurrence == 'Does not repeat' ? null : result.recurrence)));
    }
  }
}

class _EventDraft {
  const _EventDraft(this.title, this.date, this.time, this.type, this.location, this.recurrence);
  final String title;
  final DateTime date;
  final String? time;
  final String? type;
  final String? location;
  final String recurrence;
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet({required this.date});
  final DateTime date;
  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  TimeOfDay? _time;
  late DateTime _date;
  String _type = 'General';
  String _recurrence = 'Does not repeat';
  final _customIntervalController = TextEditingController(text: '1');
  String _customUnit = 'day(s)';

  @override
  void initState() {
    super.initState();
    _date = widget.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add a little joy', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(controller: _titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Event name', prefixIcon: Icon(Icons.auto_awesome))),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: Text(_formatDate(_date)), trailing: const Icon(Icons.edit_calendar_outlined), onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _date); if (picked != null) setState(() => _date = picked); }),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule), title: Text(_time == null ? 'Add time (optional)' : _time!.format(context)), onTap: () async { final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now()); if (picked != null) setState(() => _time = picked); }),
          DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Event type (optional)', prefixIcon: Icon(Icons.category_outlined)), items: const ['General', 'Work', 'Social', 'Health', 'Travel', 'Birthday'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) setState(() => _type = value); }),
          const SizedBox(height: 12),
          TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location (optional)', prefixIcon: Icon(Icons.place_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: _recurrence, decoration: const InputDecoration(labelText: 'Repeat'), items: const ['Does not repeat', 'Daily', 'Weekly', 'Monthly', 'Annually', 'Custom'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) setState(() => _recurrence = value); }),
          if (_recurrence == 'Custom') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _customIntervalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Every', prefixIcon: Icon(Icons.repeat)))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _customUnit, decoration: const InputDecoration(labelText: 'Unit'), items: const ['day(s)', 'month(s)'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) setState(() => _customUnit = value); })),
            ]),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final interval = int.tryParse(_customIntervalController.text.trim());
              if (_titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an event name before saving.')));
                return;
              }
              if (_recurrence == 'Custom' && (interval == null || interval < 1)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom repeat must be at least 1 day or month.')));
                return;
              }
              final repeat = _recurrence == 'Custom' ? 'Every $interval $_customUnit' : _recurrence;
              Navigator.pop(context, _EventDraft(_titleController.text.trim(), _date, _time?.format(context), _type == 'General' ? null : _type, _locationController.text.trim().isEmpty ? null : _locationController.text.trim(), repeat));
            },
            icon: const Icon(Icons.check),
            label: const Text('Save event'),
          ),
        ]),
      );
}

class OmnioEvent {
  OmnioEvent(this.title, this.date, {this.time, this.type, this.location, this.recurrence});
  final String title;
  final DateTime date;
  final String? time;
  final String? type;
  final String? location;
  final String? recurrence;
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.events, required this.onCalendar, required this.onLocation});
  final List<OmnioEvent> events;
  final VoidCallback onCalendar;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good afternoon!', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            Text('Make today matter.', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height: 24),
        const _WeatherCard(),
        const SizedBox(height: 24),
        Text('Quick actions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ActionCard(icon: Icons.calendar_month, label: 'Plan a day', color: Colors.orange, onTap: onCalendar)),
          const SizedBox(width: 12),
          Expanded(child: _ActionCard(icon: Icons.share_location, label: 'Share location', color: Colors.teal, onTap: onLocation)),
        ]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Coming up', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          TextButton(onPressed: onCalendar, child: const Text('See all')),
        ]),
        ...events.take(3).map((event) => _EventTile(event: event)),
      ]),
    );
  }
}

class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  late Future<_WeatherSummary?> _weather;

  @override
  void initState() {
    super.initState();
    _weather = _loadWeather();
  }

  Future<_WeatherSummary?> _loadWeather() async {
    if (!await Permission.locationWhenInUse.isGranted) return null;
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>?;
    if (current == null) return null;
    return _WeatherSummary(
      (current['temperature_2m'] as num).toDouble(),
      _weatherLabel((current['weather_code'] as num).toInt()),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_WeatherSummary?>(
        future: _weather,
        builder: (context, snapshot) {
          final weather = snapshot.data;
          if (weather == null) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Local weather'),
                subtitle: Text(snapshot.connectionState == ConnectionState.waiting ? 'Checking your last known location…' : 'Enable location to see local weather'),
              ),
            );
          }
          return _GradientCard(child: Row(children: [
            Icon(Icons.wb_sunny_outlined, color: Colors.amber.shade200, size: 42),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Local weather', style: TextStyle(color: Colors.white70)),
              Text('${weather.temperature.toStringAsFixed(0)}°C · ${weather.label}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
              const Text('At your last known location', style: TextStyle(color: Colors.white70)),
            ])),
            IconButton(onPressed: () => setState(() => _weather = _loadWeather()), icon: const Icon(Icons.refresh, color: Colors.white)),
          ]));
        },
      );
}

class _WeatherSummary {
  const _WeatherSummary(this.temperature, this.label);
  final double temperature;
  final String label;
}

String _weatherLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 48) return 'Foggy';
  if (code <= 67) return 'Rainy';
  if (code <= 77) return 'Snowy';
  if (code <= 82) return 'Showers';
  return 'Stormy';
}

class _CalendarPage extends StatefulWidget {
  const _CalendarPage({required this.events, required this.onAdd});
  final List<OmnioEvent> events;
  final ValueChanged<DateTime> onAdd;
  @override
  State<_CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<_CalendarPage> {
  DateTime _selected = DateTime.now();
  bool _showLunar = true;
  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_selected.year, _selected.month + 1, 0).day;
    final month = List.generate(daysInMonth, (index) => DateTime(_selected.year, _selected.month, index + 1));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Calendar', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          FilledButton.icon(onPressed: () => widget.onAdd(_selected), icon: const Icon(Icons.add), label: const Text('Event')),
        ]),
        const SizedBox(height: 8),
        Text('Keep your moments in one happy place.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show lunar dates'), subtitle: const Text('A simple lunar reference'), value: _showLunar, onChanged: (value) => setState(() => _showLunar = value)),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: () => setState(() => _selected = DateTime(_selected.year, _selected.month - 1)), icon: const Icon(Icons.chevron_left)),
            Text('${_monthName(_selected.month)} ${_selected.year}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => setState(() => _selected = DateTime(_selected.year, _selected.month + 1)), icon: const Icon(Icons.chevron_right)),
          ]),
          Row(children: const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) => Expanded(child: Center(child: Text(day, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))))).toList()),
          const SizedBox(height: 8),
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 4), itemCount: month.length + DateTime(_selected.year, _selected.month, 1).weekday - 1, itemBuilder: (context, index) {
            if (index < DateTime(_selected.year, _selected.month, 1).weekday - 1) return const SizedBox.shrink();
            index -= DateTime(_selected.year, _selected.month, 1).weekday - 1;
            final day = month[index];
            final selected = day.day == _selected.day && day.month == _selected.month && day.year == _selected.year;
            return InkWell(onTap: () => setState(() => _selected = day), borderRadius: BorderRadius.circular(12), child: AnimatedContainer(duration: const Duration(milliseconds: 200), decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.primary : null, borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${day.day}', style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : null)), if (_showLunar) Text('${(day.day % 29) + 1}', style: TextStyle(fontSize: 9, color: selected ? Colors.white70 : Theme.of(context).colorScheme.secondary))])));
          }),
        ]))),
        const SizedBox(height: 20),
        Text('On ${_formatDate(_selected)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.events.where((event) => event.date.day == _selected.day).map((event) => _EventTile(event: event)),
      ]),
    );
  }
}

class _LocationPage extends StatefulWidget {
  const _LocationPage();
  @override
  State<_LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<_LocationPage> {
  bool _sharing = true;
  bool _batterySaver = true;
  bool _locationPermission = false;
  bool _optimizationDisabled = false;
  bool _notificationPermission = false;
  String? _currentPosition;
  DateTime _lastUpdated = DateTime.now();
  Timer? _updateTimer;
  final people = <String, bool>{'Maya · Home': true, 'Rafi · Work': false};
  final List<_ArrivalAlert> _alerts = [
    _ArrivalAlert('Maya · Home', 'Home', 'arrives', 0, 0),
  ];

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    _updateTimer?.cancel();
    if (!_sharing || !_locationPermission) return;
    _updateTimer = Timer.periodic(
      Duration(seconds: _batterySaver ? 15 : 5),
      (_) {
        if (mounted) setState(() => _lastUpdated = DateTime.now());
      },
    );
  }

  Future<void> _refreshPermissionStatus() async {
    final location = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;
    final battery = await Permission.ignoreBatteryOptimizations.status;
    if (mounted) {
      setState(() {
        _locationPermission = location.isGranted;
        if (!location.isGranted) _sharing = false;
        _notificationPermission = notification.isGranted;
        _optimizationDisabled = battery.isGranted;
      });
    }
  }

  Future<void> _enableLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    var permission = await Permission.locationWhenInUse.request();
    if (permission.isGranted) {
      permission = await Permission.locationAlways.request();
    }
    if (permission.isGranted) {
      await Permission.notification.request();
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _locationPermission = true;
          _currentPosition = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      }
    } else if (permission.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _enableBatteryOptimizationExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (mounted) setState(() => _optimizationDisabled = status.isGranted);
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  Future<void> _enableNotifications() async {
    final status = await Permission.notification.request();
    if (mounted) setState(() => _notificationPermission = status.isGranted);
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  Future<void> _addArrivalAlert() async {
    final result = await showModalBottomSheet<_ArrivalAlert>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ArrivalAlertSheet(),
    );
    if (result != null) {
      if (result.person.isEmpty || result.place.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add both a person and a place for this alert.')));
      } else if (mounted) {
        setState(() => _alerts.add(result));
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('People', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('Share safely, stay connected, use less battery.'),
    const SizedBox(height: 20),
    if (!_locationPermission || !_notificationPermission || !_optimizationDisabled) Card(child: Column(children: [
      if (!_locationPermission) ListTile(leading: const Icon(Icons.location_disabled), title: const Text('Location access is off'), subtitle: Text(_currentPosition ?? 'Enable it to share your live location in the background.'), trailing: TextButton(onPressed: _enableLocation, child: const Text('Enable'))),
      if (!_notificationPermission) ListTile(leading: const Icon(Icons.notifications_none), title: const Text('Notifications are off'), subtitle: const Text('Enable reminders and sharing status updates.'), trailing: TextButton(onPressed: _enableNotifications, child: const Text('Enable'))),
      if (!_optimizationDisabled) ListTile(leading: const Icon(Icons.battery_alert), title: const Text('Battery optimization is on'), subtitle: const Text('Allow Omnio to run reliably in the background.'), trailing: TextButton(onPressed: _enableBatteryOptimizationExemption, child: const Text('Allow'))),
    ])),
    const SizedBox(height: 12),
    _GradientCard(child: Row(children: [Icon(_sharing ? Icons.location_on : Icons.location_off, color: Colors.white, size: 38), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Location sharing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text(_sharing ? 'Live · updated ${_lastUpdated.hour.toString().padLeft(2, '0')}:${_lastUpdated.minute.toString().padLeft(2, '0')}' : 'Disabled until location access is enabled', style: const TextStyle(color: Colors.white70))])), Switch(value: _sharing, onChanged: (value) { if (!_locationPermission) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location access above before sharing your location.'))); return; } setState(() => _sharing = value); _startLocationUpdates(); }, activeThumbColor: Colors.white)])),
    const SizedBox(height: 20),
    Card(child: Column(children: [for (final entry in people.entries) SwitchListTile(secondary: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: Icon(Icons.person, color: Theme.of(context).colorScheme.secondary)), title: Text(entry.key), subtitle: Text(entry.value ? 'Live · updates every ${_batterySaver ? 15 : 5} sec' : 'Not sharing'), value: entry.value, onChanged: (value) => setState(() => people[entry.key] = value)), const Divider(height: 1), ListTile(leading: const Icon(Icons.person_add_alt_1), title: const Text('Invite someone'), trailing: const Icon(Icons.chevron_right), onTap: () {})])),
    const SizedBox(height: 20),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Arrival alerts', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      IconButton.filledTonal(onPressed: _addArrivalAlert, icon: const Icon(Icons.add_alert_outlined)),
    ]),
    const Text('Independent rules: choose any person and any place.'),
    const SizedBox(height: 8),
    Card(child: Column(children: [
      for (final alert in _alerts) ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text('${alert.person} ${alert.action} ${alert.place}'),
        subtitle: Text('${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)} · Notify me when this happens'),
        trailing: IconButton(onPressed: () => setState(() => _alerts.remove(alert)), icon: const Icon(Icons.delete_outline)),
      ),
      if (_alerts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No alerts yet. Add one for a person or yourself.')),
    ])),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Battery saver'), subtitle: Text(_batterySaver ? 'Updates every 15 seconds while sharing' : 'Updates every 5 seconds while sharing'), value: _batterySaver, onChanged: _locationPermission ? (value) { setState(() => _batterySaver = value); _startLocationUpdates(); } : null),
  ]));
}

class _ArrivalAlert {
  const _ArrivalAlert(this.person, this.place, this.action, this.latitude, this.longitude);
  final String person;
  final String place;
  final String action;
  final double latitude;
  final double longitude;
}

class _ArrivalAlertSheet extends StatefulWidget {
  const _ArrivalAlertSheet();

  @override
  State<_ArrivalAlertSheet> createState() => _ArrivalAlertSheetState();
}

class _ArrivalAlertSheetState extends State<_ArrivalAlertSheet> {
  final _personController = TextEditingController(text: 'You');
  String _action = 'arrives';
  _MapPoint? _point;

  @override
  void dispose() {
    _personController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('New arrival alert', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(controller: _personController, decoration: const InputDecoration(labelText: 'Person (for example: You or Maya)')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_pin),
            title: Text(_point == null ? 'Choose a point on the map' : _point!.label),
            subtitle: Text(_point == null ? 'Tap the exact place for this reminder' : '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}'),
            trailing: const Icon(Icons.map_outlined),
            onTap: () async {
              final selected = await Navigator.of(context).push<_MapPoint>(MaterialPageRoute(builder: (_) => _MapPointPicker(initialPoint: _point)));
              if (selected != null && mounted) setState(() => _point = selected);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _action,
            decoration: const InputDecoration(labelText: 'When they…'),
            items: const ['arrives', 'leaves'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _action = value);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (_personController.text.trim().isEmpty || _point == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a person and a point on the map.')));
                return;
              }
              Navigator.pop(context, _ArrivalAlert(_personController.text.trim(), _point!.label, _action, _point!.latitude, _point!.longitude));
            },
            child: const Text('Save alert'),
          ),
        ]),
      );
}

class _MapPoint {
  const _MapPoint(this.label, this.latitude, this.longitude);
  final String label;
  final double latitude;
  final double longitude;
}

class _MapPointPicker extends StatefulWidget {
  const _MapPointPicker({this.initialPoint});
  final _MapPoint? initialPoint;

  @override
  State<_MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends State<_MapPointPicker> {
  late LatLng _center;
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    final point = widget.initialPoint;
    _center = point == null ? const LatLng(-6.200000, 106.816666) : LatLng(point.latitude, point.longitude);
    _selected = point == null ? null : _center;
    _centerOnDevice();
  }

  Future<void> _centerOnDevice() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    final position = await Geolocator.getLastKnownPosition();
    if (position != null && mounted && widget.initialPoint == null) {
      setState(() => _center = LatLng(position.latitude, position.longitude));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Choose a point'),
          actions: [
            TextButton(
              onPressed: _selected == null ? null : () {
                final point = _selected!;
                Navigator.pop(context, _MapPoint('Pinned location', point.latitude, point.longitude));
              },
              child: const Text('Save'),
            ),
          ],
        ),
        body: FlutterMap(
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 14,
            onTap: (_, point) => setState(() => _selected = point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cryptoware.omnio.omnio',
            ),
            if (_selected != null)
              MarkerLayer(markers: [
                Marker(
                  point: _selected!,
                  width: 56,
                  height: 56,
                  child: Icon(Icons.location_pin, color: Theme.of(context).colorScheme.primary, size: 48),
                ),
              ]),
          ],
        ),
      );
}

class _ScraperPage extends StatefulWidget {
  const _ScraperPage();
  @override
  State<_ScraperPage> createState() => _ScraperPageState();
}

class _ScraperPageState extends State<_ScraperPage> {
  final _query = TextEditingController();
  bool _loading = false;
  String? _error;
  List<_PriceResult> _results = [];

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _search() async {
    final term = _query.text.trim();
    if (term.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final encodedTerm = Uri.encodeQueryComponent('$term price');
      final endpoints = [
        Uri.parse('https://www.bing.com/search?q=$encodedTerm'),
        Uri.parse('https://www.google.com/search?q=$encodedTerm'),
      ];
      http.Response? response;
      for (final endpoint in endpoints) {
        final candidate = await http.get(endpoint, headers: {'User-Agent': 'Mozilla/5.0 Omnio/1.0'}).timeout(const Duration(seconds: 12));
        if (candidate.statusCode == 200) {
          response = candidate;
          break;
        }
      }
      if (response == null) throw Exception('No search provider responded.');
      final linkPattern = RegExp(r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>', dotAll: true);
      final matches = linkPattern.allMatches(response.body).where((match) => !match.group(1)!.contains('google.com/search') && !match.group(1)!.contains('bing.com/search')).take(8).toList();
      final links = matches.map((match) => match.group(1)!).toList();
      final titles = matches.map((match) => match.group(2)!.replaceAll(RegExp('<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim()).toList();
      if (mounted) {
        setState(() => _results = [
          for (var i = 0; i < links.length; i++)
            _PriceResult.fromListing(
              i < titles.length ? titles[i] : 'Public result',
              links[i],
            ),
        ]);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not fetch public results. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Price scout', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('Search public pages directly. No AI summaries, just sources.'),
    const SizedBox(height: 20),
    Row(children: [Expanded(child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'What are you looking for?'))), const SizedBox(width: 8), IconButton.filled(onPressed: _loading ? null : _search, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward))]),
    const SizedBox(height: 16),
    if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    if (!_loading && _results.isEmpty && _error == null) const Text('Type a product name to compare public listings.'),
    ..._results.map((result) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: const Icon(Icons.storefront_outlined),
            ),
            title: Text(result.price, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(result.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            trailing: IconButton.filledTonal(
              tooltip: 'Open source',
              onPressed: () => launchUrl(Uri.parse(result.url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        )),
  ]));
}

class _PriceResult {
  const _PriceResult(this.price, this.merchant, this.url);
  final String price;
  final String merchant;
  final String url;

  factory _PriceResult.fromListing(String title, String url) {
    final cleanTitle = title
        .replaceAll(RegExp(r'&(?:amp|nbsp);'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final priceMatch = RegExp(
      r'Rp\s?[\d.,]+|(?:IDR)\s?[\d.,]+',
      caseSensitive: false,
    ).firstMatch(cleanTitle);
    final merchant = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? 'Public listing';
    return _PriceResult(
      priceMatch?.group(0)?.replaceAll(' ', ' ') ?? 'Price unavailable',
      merchant.isEmpty ? 'Public listing' : merchant,
      url,
    );
  }
}

class _OmnioDock extends StatelessWidget {
  const _OmnioDock({required this.selectedIndex, required this.onSelected, required this.onMore});
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home, 'Today', 0),
      (Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar', 1),
      (Icons.location_on_outlined, Icons.location_on, 'People', 2),
    ];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(children: [
          for (final item in items)
            Expanded(child: _DockItem(icon: selectedIndex == item.$4 ? item.$2 : item.$1, label: item.$3, selected: selectedIndex == item.$4, onTap: () => onSelected(item.$4))),
          Expanded(child: _DockItem(icon: Icons.grid_view_rounded, label: 'More', selected: selectedIndex > 2, onTap: onMore)),
        ]),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.primaryContainer : null, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      );
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), const Text('This module is ready for your next idea.', textAlign: TextAlign.center)])));
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.displayName, required this.onLogout, required this.onToggleTheme});
  final String displayName;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(radius: 32, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text(displayName.substring(0, 1).toUpperCase(), style: Theme.of(context).textTheme.headlineSmall)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Demo account · local session')])),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.brightness_6_outlined), title: const Text('Switch theme'), subtitle: const Text('Your choice is saved on this device'), trailing: IconButton(onPressed: onToggleTheme, icon: const Icon(Icons.chevron_right))),
            const Divider(height: 1),
            const ListTile(leading: Icon(Icons.notifications_none), title: Text('Notifications'), subtitle: Text('Manage reminders and updates'), trailing: Icon(Icons.chevron_right)),
            const Divider(height: 1),
            const ListTile(leading: Icon(Icons.shield_outlined), title: Text('Privacy & permissions'), subtitle: Text('Location and background access'), trailing: Icon(Icons.chevron_right)),
          ])),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Sign out'), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48))),
        ]),
      );
}

class _GradientCard extends StatelessWidget {
  const _GradientCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: child);
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 12),
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final OmnioEvent event;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(_eventIcon(event.type), color: Theme.of(context).colorScheme.primary)), title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${_formatDate(event.date)}${event.time == null ? '' : ' · ${event.time}'}${event.recurrence == null ? '' : ' · ${event.recurrence}'}${event.location == null ? '' : ' · ${event.location}'}')));
}

String _monthName(int month) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];
String _formatDate(DateTime date) => '${_weekdayName(date.weekday)}, ${date.day} ${_monthName(date.month)} ${date.year}';
String _weekdayName(int weekday) => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday - 1];
IconData _eventIcon(String? type) => switch (type) {
      'Work' => Icons.work_outline,
      'Social' => Icons.groups_outlined,
      'Health' => Icons.favorite_border,
      'Travel' => Icons.flight_takeoff,
      'Birthday' => Icons.cake_outlined,
      _ => Icons.event_outlined,
    };
