part of 'settings_page.dart';

class Anime4KSettings extends StatefulWidget {
  const Anime4KSettings({super.key});

  @override
  State<Anime4KSettings> createState() => _Anime4KSettingsState();
}

class _Anime4KSettingsState extends State<Anime4KSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Anime4K".tl)),
        _SwitchSetting(
          title: "Enable Anime4K Upscaling".tl,
          settingKey: "enableAnime4K",
        ).toSliver(),
        _SliderSetting(
          title: "Scale Factor".tl,
          settingsIndex: "anime4KScaleFactor",
          min: 1.0,
          max: 4.0,
          interval: 0.5,
        ).toSliver(),
        _SliderSetting(
          title: "Push Strength".tl,
          settingsIndex: "anime4KPushStrength",
          min: 0.0,
          max: 1.0,
          interval: 0.05,
        ).toSliver(),
        _SliderSetting(
          title: "Gradient Refine Strength".tl,
          settingsIndex: "anime4KPushGradStrength",
          min: 0.0,
          max: 1.0,
          interval: 0.05,
        ).toSliver(),
        ListTile(
          title: Text("Clear Anime4K Cache".tl),
          trailing: const Icon(Icons.delete_sweep),
          onTap: () async {
            await Anime4KService.instance.clearCache();
            if (mounted) {
              context.showMessage(message: "Anime4K cache cleared".tl);
            }
          },
        ).toSliver(),
      ],
    );
  }
}
