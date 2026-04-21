import 'package:flutter_test/flutter_test.dart';

import 'package:video_download/services/download_support.dart';

void main() {
  test('preferSecureUri upgrades http links to https', () {
    final uri = Uri.parse('http://i1.hdslb.com/bfs/archive/demo.jpg');

    expect(preferSecureUri(uri).toString(), 'https://i1.hdslb.com/bfs/archive/demo.jpg');
  });

  test('preferSecureUri keeps secure links unchanged', () {
    final uri = Uri.parse('https://example.com/cover.jpg');

    expect(preferSecureUri(uri), uri);
  });
}
