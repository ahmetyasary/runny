import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runny/app.dart';

void main() {
  testWidgets('Splash sonrası ana akışı gösterir', (WidgetTester tester) async {
    await tester.pumpWidget(const RunnyApp());

    expect(find.text('Yükleniyor...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.textContaining('Günaydın'), findsOneWidget);
    expect(find.text('Arkadaşlarından'), findsOneWidget);
  });

  testWidgets('Aktivite başlatma seçeneklerini açar', (WidgetTester tester) async {
    await tester.pumpWidget(const RunnyApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Aktivite başlat'), findsOneWidget);
    expect(find.text('Koşu'), findsOneWidget);
  });
}
