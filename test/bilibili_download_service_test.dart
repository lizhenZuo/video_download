import 'package:flutter_test/flutter_test.dart';

import 'package:video_download/services/bilibili_download_service.dart';

void main() {
  test('extractBilibiliInitialState parses embedded json payload', () {
    const html = '''
<script>
window.__INITIAL_STATE__={"video":{"viewInfo":{"bvid":"BV1abc123","title":"测试标题","pic":"http://i1.hdslb.com/demo.jpg","owner":{"name":"测试作者"},"stat":{"view":12345},"duration":9,"desc":"测试描述","pages":[{"first_frame":"http://i1.hdslb.com/frame.jpg"}]},"playUrlInfo":[{"order":1,"length":8545,"size":417818,"url":"https://example.com/video.mp4"}]}};
(function(){var s;(s=document.currentScript||document.scripts[document.scripts.length-1]).parentNode.removeChild(s);}());
</script>
''';

    final state = extractBilibiliInitialState(html);
    final video = state['video'] as Map<String, dynamic>;
    final viewInfo = video['viewInfo'] as Map<String, dynamic>;
    final playUrlInfo = video['playUrlInfo'] as List<dynamic>;

    expect(viewInfo['bvid'], 'BV1abc123');
    expect(viewInfo['title'], '测试标题');
    expect((playUrlInfo.first as Map<String, dynamic>)['url'], 'https://example.com/video.mp4');
  });
}
