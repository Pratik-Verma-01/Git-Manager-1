import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/glass/animated_background.dart';

class GitManagerApp extends ConsumerWidget {
  const GitManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // AuroraBackgroundScope sits above the router so every route's
    // AnimatedAuroraBackground shares one ticker instead of starting a
    // fresh animation (and losing its phase) on every navigation.
    return AuroraBackgroundScope(
      child: MaterialApp.router(
        title: 'Git Manager',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    );
  }
}
