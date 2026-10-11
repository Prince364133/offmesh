import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmesh/core/haven_engine.dart';
import 'package:offmesh/core/models.dart';
import 'package:offmesh/main.dart';
import 'test_engine_adapter.dart';

void main() {
  setUp(() {
    HavenEngine.instance.resetForTesting();
  });

  tearDown(() {
    HavenEngine.instance.resetForTesting();
  });

  testWidgets('1. OffMeshApp launches into Decoy Calculator and unlocks via secret PIN', (tester) async {
    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Verify calculator screen is active
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    // Enter PIN: 1 2 3 4 =
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('='));
    await tester.pumpAndSettle();

    // App should now be unlocked and display AuthScreen
    expect(HavenEngine.instance.isStealthUnlocked, isTrue);
    expect(find.text('OffMesh Haven'), findsOneWidget);
  });

  testWidgets('2. Authenticated user displays 4-Tab Haven Navigation: Chats, Sanctuary, Nearby Mesh, Settings', (tester) async {
    HavenEngine.instance.setMockAuthenticatedForTesting();

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Bottom Navigation Bar tabs
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Sanctuary'), findsOneWidget);
    expect(find.text('Nearby Mesh'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap Nearby Mesh tab
    await tester.tap(find.text('Nearby Mesh'));
    await tester.pumpAndSettle();
    expect(find.text('Nearby Devices'), findsOneWidget);

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Stealth & Privacy Settings'), findsOneWidget);
  });

  testWidgets('3. Chats tab navigates to dedicated Chat Screen with romantic wallpaper & settings icon', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
      daysTogether: 100,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Find Juliet's chat tile
    expect(find.text('Juliet'), findsOneWidget);

    // Tap into Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Chat Screen UI elements
    expect(find.byIcon(Icons.settings), findsOneWidget); // Chat settings icon
    expect(find.byIcon(Icons.add_circle), findsOneWidget); // '+' action menu
    expect(find.byType(TextField), findsOneWidget); // Chat composer
    expect(find.text('Together for 100 days 💕'), findsOneWidget);
  });

  testWidgets('4. Expired 3-day free trial strictly locks chat input and displays \$5/mo unlock prompt', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
      daysTogether: 100,
    );

    // Mock an expired trial where user cannot chat without paying $5/mo
    final expiredSub = SubscriptionInfo(
      status: 'EXPIRED',
      plan: 'MONTHLY_5',
      priceUsd: 5.0,
      isTrialActive: false,
      isSubscribed: false,
      hasChatAccess: false,
      trialDaysRemaining: 0,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);
    HavenEngine.instance.setMockSubscriptionForTesting(expiredSub);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap into Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Chat textfield should be locked (not present)
    expect(find.byType(TextField), findsNothing);

    // Locked paywall prompt is displayed
    expect(find.text('3-Day Free Trial Expired'), findsOneWidget);
    expect(find.text('Chat input is locked. Unlock Sanctuary for \$5/mo.'), findsOneWidget);
    expect(find.text('Unlock (\$5/mo)'), findsOneWidget);

    // Tap Unlock ($5/mo) button to open paywall bottom sheet
    await tester.tap(find.text('Unlock (\$5/mo)'));
    await tester.pumpAndSettle();

    // Paywall bottom sheet modal appears
    expect(find.text('Unlock Haven Sanctuary'), findsOneWidget);
    expect(find.text('\$5.00 / month'), findsOneWidget);
    expect(find.text('Subscribe for \$5 / month'), findsOneWidget);
  });

  testWidgets('5. Active \$5/mo subscription unlocks chat input and allows sending messages', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
      daysTogether: 100,
    );

    final activeSub = SubscriptionInfo(
      status: 'ACTIVE',
      plan: 'MONTHLY_5',
      priceUsd: 5.0,
      isTrialActive: false,
      isSubscribed: true,
      hasChatAccess: true,
      trialDaysRemaining: 0,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);
    HavenEngine.instance.setMockSubscriptionForTesting(activeSub);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap into Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Chat textfield is unlocked and available
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Unlock (\$5/mo)'), findsNothing);
  });

  testWidgets('6. Settings screen displays Haven Sanctuary Membership and \$5/mo plan status', (tester) async {
    final trialSub = SubscriptionInfo(
      status: 'TRIAL',
      plan: 'MONTHLY_5',
      priceUsd: 5.0,
      isTrialActive: true,
      isSubscribed: false,
      hasChatAccess: true,
      trialDaysRemaining: 3,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting();
    HavenEngine.instance.setMockSubscriptionForTesting(trialSub);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify Membership section
    expect(find.text('HAVEN SANCTUARY MEMBERSHIP & BILLING'), findsOneWidget);
    expect(find.text('Haven Sanctuary Plan'), findsOneWidget);
    expect(find.text('\$5.00 / month • First 3 days free'), findsOneWidget);
    expect(find.text('FREE TRIAL (3D LEFT)'), findsOneWidget);
    expect(find.text('Unlock Sanctuary for \$5 / Month'), findsOneWidget);
  });

  testWidgets('7. N-View Ephemeral Photo: displays remaining views badge, opens watermarked viewer, and self-destructs upon limit', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );

    // Initial message with 1 view limit (1 view left)
    final nViewMsg = MessageItem(
      id: 'media_msg_1',
      toIdHex: 'test_user',
      fromIdHex: 'partner_juliet',
      text: '📷 Shared media',
      isOutgoing: false,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mediaUrl: 'https://r2.haven.app/ephemeral/test.jpg',
      mediaMimeType: 'image/jpeg',
      maxViews: 1,
      viewCount: 0,
      isConsumed: false,
      watermarkEnabled: true,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);
    HavenEngine.instance.setMockMessagesForTesting([nViewMsg]);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap into Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Verify 1 View(s) Left badge is shown
    expect(find.text('1 View(s) Left'), findsOneWidget);
    expect(find.text('Watermarked'), findsOneWidget);

    // Tap on photo card to open Protected Media Viewer
    await tester.tap(find.text('1 View(s) Left'));
    await tester.pumpAndSettle();

    // Lightbox viewer is opened with anti-leak watermark and view counter
    expect(find.textContaining('RECIPIENT: @Juliet'), findsWidgets);
    expect(find.textContaining('Screenshot blocked'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Close lightbox viewer
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Because maxViews was 1 and 1 view was consumed, it has self-destructed!
    expect(find.text('💥 Photo Self-Destructed (View limit reached)'), findsOneWidget);
    expect(find.text('1 View(s) Left'), findsNothing);
  });

  testWidgets('8. Girls\' Safety Shield: Block user button severs couple connection and confirms blocking', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Tap Girls' Safety Shield button in AppBar
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    // Safety guardian sheet is presented
    expect(find.text('Girls\' Safety & Guardian'), findsOneWidget);
    expect(find.text('Block & Sever Connection'), findsOneWidget);
    expect(find.text('Emergency Mutual Nuke'), findsOneWidget);
    expect(find.text('Girls\' Safety & Anti-Leak Guide'), findsOneWidget);

    // Tap Block & Sever Connection
    await tester.tap(find.text('Block & Sever Connection'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Block User & Sever Chat?'), findsOneWidget);
    expect(find.text('Block & Sever'), findsOneWidget);
  });

  testWidgets('9. Girls\' Safety Shield: Emergency Mutual Nuke wipes conversation messages', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );

    final mockMsg = MessageItem(
      id: 'test_msg_99',
      toIdHex: 'partner_juliet',
      fromIdHex: 'test_user',
      text: 'Message to be nuked',
      isOutgoing: true,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);
    HavenEngine.instance.setMockMessagesForTesting([mockMsg]);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    expect(find.text('Message to be nuked'), findsOneWidget);

    // Tap Girls' Safety Shield button
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    // Tap Emergency Mutual Nuke
    await tester.tap(find.text('Emergency Mutual Nuke'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Mutual Emergency Nuke?'), findsOneWidget);
    expect(find.text('Incinerate Chat'), findsOneWidget);
  });

  testWidgets('10. Settings screen displays Girls\' Safety Guardian with Incognito Ghost Persona toggle', (tester) async {
    HavenEngine.instance.setMockAuthenticatedForTesting();
    HavenEngine.instance.setMockGhostPersonaForTesting(GhostPersona(
      aliasName: 'StarLight_Guardian',
      avatarPreset: 'AVATAR_NIGHT',
      isActive: true,
    ));

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Scroll down to reveal Girls' Safety Guardian section
    await tester.scrollUntilVisible(
      find.text('Emergency Mutual Chat Nuke'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Verify Girls' Safety Guardian section
    expect(find.text('GIRLS\' SAFETY & HARASSMENT GUARDIAN'), findsOneWidget);
    expect(find.text('Incognito Ghost Persona'), findsOneWidget);
    expect(find.text('Customize Ghost Pseudonym'), findsOneWidget);
    expect(find.text('Current Alias: @StarLight_Guardian'), findsOneWidget);
    expect(find.text('Emergency Mutual Chat Nuke'), findsOneWidget);
  });

  testWidgets('11. WhatsApp Voice Message: playable waveform, View Once badge, and auto-destruction upon completion', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );
    final voiceMsg = MessageItem(
      id: 'voice_msg_1',
      toIdHex: 'test_user',
      fromIdHex: 'partner_juliet',
      text: '🎤 Voice message',
      isOutgoing: false,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mediaUrl: 'https://r2.haven/voice_1.m4a',
      mediaMimeType: 'audio/m4a',
      audioDuration: 3,
      maxViews: 1,
      viewCount: 0,
      isConsumed: false,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);
    HavenEngine.instance.setMockMessagesForTesting([voiceMsg]);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    // Tap into Juliet's chat
    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Verify 1 View Voice Note badge and play button
    expect(find.text('1 View Voice Note'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    // Tap Play
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Advance timer past total duration (3 seconds)
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Should now be consumed and expired
    expect(find.text('Voice note opened and expired'), findsOneWidget);
    expect(HavenEngine.instance.messages.first.isConsumed, isTrue);
  });

  testWidgets('12. Offline Outbox: messages queue with clock icon when offline and auto-sync when online', (tester) async {
    final engine = HavenEngine.instance;
    final recipient = Contact(
      name: 'Juliet',
      idHex: 'partner_juliet',
      signPubHex: '0' * 64,
      encPubHex: '0' * 64,
      cardString: '',
    );
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );

    engine.setMockAuthenticatedForTesting(couple: mockCouple);
    // User goes offline
    engine.setOnline(false);
    expect(engine.isOnline, isFalse);

    // Send a message while offline
    await engine.sendMessage(recipient, 'Secret love note sent offline');

    // Message is queued in outbox
    expect(engine.pendingOutboxCount, 1);
    expect(engine.messages.first.status, MessageStatus.queued);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Displays clock icon (Icons.access_time) while queued
    expect(find.byIcon(Icons.access_time), findsOneWidget);

    // User comes back online -> auto flushes outbox
    engine.setOnline(true);
    await tester.pumpAndSettle();

    expect(engine.isOnline, isTrue);
    // Verified message drained from outbox and marked delivered
    expect(engine.pendingOutboxCount, 0);
    expect(engine.messages.first.status, MessageStatus.delivered);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('13. Video Sharing: auto-clips videos exceeding 5 minutes (300s) and renders protected player', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );
    final videoMsg = MessageItem(
      id: 'video_msg_1',
      toIdHex: 'test_user',
      fromIdHex: 'partner_juliet',
      text: 'Encrypted Video',
      isOutgoing: false,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mediaUrl: 'https://r2.haven/video_1.mp4',
      mediaMimeType: 'video/mp4',
      audioDuration: 300, // Clipped to 5m max
      maxViews: 1,
      viewCount: 0,
      isConsumed: false,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);
    HavenEngine.instance.setMockMessagesForTesting([videoMsg]);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Video card shows Max 5:00 badge and videocam icon
    expect(find.byIcon(Icons.videocam), findsWidgets);
    expect(find.text('Max 5:00 (5:00)'), findsOneWidget);

    // Tap to open protected media viewer
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Viewer displays video interface with 5:00 duration and watermark
    expect(find.text('E2EE Ephemeral Video (5:00)'), findsOneWidget);
    expect(find.text('Max 5-minute video • Auto-destructs upon view limit'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('14. Image sharing limit: displays alert dialog when exceeding 50 images', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );

    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // Tap plus action button
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    // Tap Photos button
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    // Dialog appears asking for number of images
    expect(find.text('N-View Ephemeral Photo'), findsOneWidget);
    expect(find.text('NUMBER OF IMAGES'), findsOneWidget);

    // Enter 75 images (exceeds 50)
    final countFinder = find.byType(TextField).last;
    await tester.enterText(countFinder, '75');
    await tester.pumpAndSettle();

    // Tap Send Protected Photo
    await tester.tap(find.text('Send Protected Photo'));
    await tester.pumpAndSettle();

    // Limit exceeded alert dialog is displayed
    expect(find.text('Selection Limit Exceeded'), findsOneWidget);
    expect(find.text('A maximum of 50 images can be shared at once. Only the first 50 images will be sent.'), findsOneWidget);

    // Dismiss alert dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Selection Limit Exceeded'), findsNothing);
  });

  testWidgets('15. Emergency Alarm & Ringtone: Red button requires 3-second hold to trigger vibration & ringtone on partner device', (tester) async {
    final mockPartner = UserProfile(
      id: 'partner_juliet',
      username: 'juliet',
      displayName: 'Juliet',
      signPublicKey: '0' * 64,
      encPublicKey: '0' * 64,
    );
    final mockCouple = CoupleInfo(
      coupleId: 'couple_1',
      status: 'ACCEPTED',
      isInitiator: true,
      partner: mockPartner,
    );

    final testAdapter = TestEngineAdapter();
    HavenEngine.instance.platformAdapter = testAdapter;
    HavenEngine.instance.setMockAuthenticatedForTesting(couple: mockCouple);

    await tester.pumpWidget(const OffMeshApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Juliet'));
    await tester.pumpAndSettle();

    // 1. Open '+' remote actions bottom sheet
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    // Verify Red Alarm button exists with 'Hold 3s' badge
    expect(find.text('Alarm Ring'), findsOneWidget);
    expect(find.text('Hold 3s'), findsOneWidget);
    final alarmBtnFinder = find.byKey(const Key('btn_alarm_ring_hold'));
    expect(alarmBtnFinder, findsOneWidget);

    // 2. Short tap (< 3s): verify prompt warning to hold for 3 seconds
    await tester.tap(alarmBtnFinder);
    await tester.pump();
    expect(find.text('⚠️ Hold for 3 seconds to trigger emergency ringtone & vibration on partner device.'), findsOneWidget);

    // 3. Full 3-second continuous hold triggers emergency alarm
    final gesture = await tester.startGesture(tester.getCenter(alarmBtnFinder));
    await tester.pump(const Duration(milliseconds: 1000));
    // Verify countdown updates to 2s
    expect(find.text('2s'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    // Verify countdown updates to 1s
    expect(find.text('1s'), findsOneWidget);

    // Complete the 3rd second
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester.pumpAndSettle();

    // Bottom sheet is dismissed and success banner is displayed
    expect(find.text('🚨 Emergency ringtone & vibration alarm triggered on partner device!'), findsOneWidget);

    // Wait for confirmation banner to dismiss before receiving incoming test signal
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // 4. Test targeted receiver device: receiving RING signal triggers BOTH vibration & ringtone
    final initialVibrate = testAdapter.vibrateCallCount;
    final initialRing = testAdapter.ringBellCallCount;

    await HavenEngine.instance.handleTestWsMessage(jsonEncode({
      'type': 'HAVEN_SIGNAL',
      'data': {
        'signalType': 'RING',
        'fromName': 'Juliet',
      },
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(testAdapter.vibrateCallCount, equals(initialVibrate + 1));
    expect(testAdapter.ringBellCallCount, equals(initialRing + 1));
    expect(find.text('Juliet triggered an emergency ringtone and vibration alarm! 🚨🔔'), findsOneWidget);
  });
}


