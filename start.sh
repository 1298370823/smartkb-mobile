# 创建项目根目录
mkdir -p ~/smart_kb_mobile
cd ~/smart_kb_mobile

# 创建 data 子目录
mkdir -p data

# ---------- 1. 创建 smart_kb_core.py ----------
cat > smart_kb_core.py << 'EOF'
# -*- coding: utf-8 -*-
"""
智能运维知识库核心算法（移动版）
- 纯 Python 实现，无 scikit-learn 依赖
- 保留 jieba 分词、SequenceMatcher 相似度
"""
import json
import re
from collections import Counter
from difflib import SequenceMatcher
from typing import List, Dict, Optional, Tuple

try:
    import jieba
    HAS_JIEBA = True
except ImportError:
    HAS_JIEBA = False

class TextProcessor:
    STOP_WORDS = {
        '的', '了', '在', '是', '和', '有', '为', '这个', '一个', '问题', '如何', '解决',
        '怎么', '什么', '为什么', '怎样', '哪个', '哪里', '何时', '多少', '是否',
        '可以', '能够', '可能', '需要', '要求', '必须', '应该', '会', '要',
        '不能', '不会', '没有', '不', '没', '无', '非', '未', '否', '别', '莫', '勿'
    }
    TECH_KEYWORDS = [
        '部署', '安装', '配置', '启动', '停止', '重启', '卸载', '升级', '降级',
        '异常', '错误', '报错', '故障', '失败', '内存', 'CPU', '磁盘', '网络',
        '端口', '连接', '超时', '日志', '数据库', '连接池', '证书', 'SSL',
        '许可证', 'license', '授权', '过期', '到期', '中间件', '集群', '负载均衡',
        '兼容', '冲突', '依赖', 'jar', 'war', '类冲突', 'ClassNotFound'
    ]

    @staticmethod
    def chinese_segment(text: str) -> List[str]:
        if not text:
            return []
        if HAS_JIEBA:
            try:
                return list(jieba.cut(text))
            except:
                pass
        words = []
        cur = ""
        for ch in text:
            if '\u4e00' <= ch <= '\u9fa5':
                if cur:
                    words.append(cur)
                    cur = ""
                words.append(ch)
            elif ch.isalnum():
                cur += ch
            else:
                if cur:
                    words.append(cur)
                    cur = ""
        if cur:
            words.append(cur)
        return words

    @staticmethod
    def extract_keywords(text: str, top_n: int = 10) -> List[str]:
        if not text:
            return []
        words = TextProcessor.chinese_segment(text.lower())
        words = [w for w in words if w not in TextProcessor.STOP_WORDS and len(w) > 1]
        freq = Counter(words)
        for w in freq:
            if w in TextProcessor.TECH_KEYWORDS:
                freq[w] *= 2
        return [w for w, _ in freq.most_common(top_n)]

    @staticmethod
    def calculate_similarity(t1: str, t2: str) -> float:
        if not t1 or not t2:
            return 0.0
        return SequenceMatcher(None, t1.lower(), t2.lower()).ratio()


class IssueClassifier:
    CATEGORIES = {
        '部署安装': ['部署', '安装', '卸载', '升级', '降级', '打包', 'war', 'jar'],
        '启动停止': ['启动', '停止', '重启', '开机', '关机', '自启', '初始化'],
        '配置管理': ['配置', '参数', '设置', '修改', '调整', 'jvm', '端口', '路径'],
        '性能调优': ['性能', '慢', '卡顿', '延迟', '超时', '优化', '调优', '内存', 'cpu'],
        '网络连接': ['网络', '连接', '端口', '访问', '通信', 'socket', 'tcp', 'http'],
        '数据库': ['数据库', '连接池', 'sql', 'jdbc', 'mysql', 'oracle', '达梦'],
        '安全认证': ['安全', '认证', '授权', '权限', '证书', 'ssl', 'tls', '加密'],
        '日志监控': ['日志', '监控', '告警', '报警', '记录', '打印', '输出'],
        '集群高可用': ['集群', '节点', '主从', '同步', '异步', '高可用', '负载均衡'],
        '许可证授权': ['许可证', 'license', '授权', '过期', '到期', '无效', '激活'],
        '兼容性': ['兼容', '冲突', '版本', '依赖', 'jar包', '类冲突'],
        '其他问题': []
    }

    @staticmethod
    def classify(problem: str, description: str = "") -> str:
        text = (problem + " " + description).lower()
        scores = {}
        for cat, kws in IssueClassifier.CATEGORIES.items():
            score = 0
            for kw in kws:
                if kw.lower() in text:
                    score += 2
                    if kw in ['license', '许可证', '授权', '过期']:
                        score += 3
            scores[cat] = score
        best = max(scores.items(), key=lambda x: x[1])
        return best[0] if best[1] > 0 else "其他问题"


class IntelligentSearcher:
    def __init__(self, qa_pairs: List[Dict]):
        self.qa_pairs = qa_pairs
        self.index = []
        for qa in qa_pairs:
            text = f"{qa['question']} {qa['answer']} {qa.get('keywords', '')}".lower()
            self.index.append(text)

    def search(self, query: str, top_k: int = 10, min_score: float = 0.1) -> List[Dict]:
        if not self.qa_pairs:
            return []
        ql = query.lower()
        qkws = TextProcessor.extract_keywords(query)

        scores = []
        for idx, qa in enumerate(self.qa_pairs):
            score = 0.0
            ql_ques = qa['question'].lower()
            if ql in ql_ques:
                score += 0.5
            if ql in qa['answer'].lower():
                score += 0.3
            for kw in qkws:
                if kw in ql_ques or kw in qa['answer'].lower() or kw in qa.get('keywords', '').lower():
                    score += 0.2
            errs = self._extract_error_patterns(query)
            for e in errs:
                if e in ql_ques or e in qa['answer'].lower():
                    score += 0.4
            if any(w in ql for w in ['license', '许可证', '授权', '过期']) and qa.get('category') == '许可证授权':
                score += 0.6
            if len(qa['answer']) > 500:
                score += 0.2
            elif len(qa['answer']) > 200:
                score += 0.1
            if score > min_score:
                scores.append((idx, score))

        scores.sort(key=lambda x: x[1], reverse=True)
        results = []
        for idx, score in scores[:top_k]:
            qa = self.qa_pairs[idx]
            results.append({
                'id': qa.get('id', f'QA{idx+1:05d}'),
                'question': qa['question'],
                'answer': qa['answer'],
                'category': qa.get('category', '其他问题'),
                'score': round(score, 3),
                'keywords': qa.get('keywords', ''),
                'source': qa.get('source', ''),
                'highlight': self._generate_highlight(query, qa)
            })
        return results

    def _extract_error_patterns(self, text: str) -> List[str]:
        pats = re.findall(r'([A-Z][a-zA-Z]*Exception|Error|Failure|Timeout)', text)
        pats += re.findall(r'[A-Z]{2,}_?\d{3,}|[A-Z]+-\d+', text)
        pats += re.findall(r'license|License|LICENSE|许可证|授权|过期|到期', text, re.IGNORECASE)
        return list(set(pats))

    def _generate_highlight(self, query: str, qa: Dict) -> str:
        ql = query.lower()
        al = qa['answer'].lower()
        if ql in al:
            idx = al.find(ql)
            s = max(0, idx - 50)
            e = min(len(al), idx + len(ql) + 50)
            return ('...' if s > 0 else '') + qa['answer'][s:e] + ('...' if e < len(al) else '')
        for kw in TextProcessor.extract_keywords(query):
            if kw.lower() in al:
                idx = al.find(kw.lower())
                s = max(0, idx - 50)
                e = min(len(al), idx + len(kw) + 50)
                return ('...' if s > 0 else '') + qa['answer'][s:e] + ('...' if e < len(al) else '')
        return qa['answer'][:100] + '...'
EOF

# ---------- 2. 创建 data/qa_pairs.json ----------
cat > data/qa_pairs.json << 'EOF'
[
  {
    "id": "QA00001",
    "category": "许可证授权",
    "question": "Error while Resizing pool seeyon. Exception: License file expired",
    "answer": "许可证文件已过期。解决方案：1. 重新申请正式授权文件；2. 替换安装目录下的 license.dat；3. 重启中间件服务。",
    "keywords": "license, 过期, 授权, seeyon",
    "source": "内置示例"
  },
  {
    "id": "QA00002",
    "category": "数据库",
    "question": "连接数据库失败，报错：Connection refused",
    "answer": "数据库连接被拒绝。请检查：1. 数据库服务是否启动；2. 连接地址和端口是否正确；3. 防火墙是否放行；4. 连接池配置是否超限。",
    "keywords": "数据库, 连接失败, 拒绝连接",
    "source": "内置示例"
  },
  {
    "id": "QA00003",
    "category": "内存溢出",
    "question": "java.lang.OutOfMemoryError: Java heap space",
    "answer": "Java堆内存溢出。解决方案：1. 增加JVM堆内存（-Xmx）；2. 检查内存泄漏；3. 优化代码，减少对象创建；4. 升级硬件配置。",
    "keywords": "内存溢出, OOM, 堆内存",
    "source": "内置示例"
  },
  {
    "id": "QA00004",
    "category": "类加载",
    "question": "ClassNotFoundException: com.example.SomeClass",
    "answer": "类找不到。请检查：1. 依赖JAR包是否完整；2. 类路径配置是否正确；3. 是否存在版本冲突；4. 检查部署包结构。",
    "keywords": "类找不到, ClassNotFoundException, 依赖缺失",
    "source": "内置示例"
  },
  {
    "id": "QA00005",
    "category": "版本冲突",
    "question": "NoSuchMethodError: org.springframework.xxx",
    "answer": "方法不存在，通常由依赖版本冲突引起。解决方案：1. 统一Spring版本；2. 使用maven依赖树排查冲突；3. 排除传递依赖。",
    "keywords": "版本冲突, 方法不存在, NoSuchMethodError",
    "source": "内置示例"
  }
]
EOF

# ---------- 3. 创建 main.py ----------
cat > main.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能运维问答系统 - Kivy 移动版
"""
import json
import os
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.uix.scrollview import ScrollView
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.properties import StringProperty
from kivy.core.window import Window
from kivy.utils import platform
from kivy.clock import Clock

from smart_kb_core import IntelligentSearcher

if platform == 'win' or platform == 'linux':
    Window.size = (400, 700)

class SearchScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.searcher = None
        layout = BoxLayout(orientation='vertical', padding=15, spacing=10)
        layout.add_widget(Label(
            text='智能运维问答系统',
            font_size='24sp',
            size_hint=(1, 0.1),
            color=(0.2, 0.7, 0.2, 1),
            bold=True
        ))
        self.search_input = TextInput(
            hint_text='输入问题或错误信息...',
            size_hint=(1, 0.1),
            multiline=False,
            font_size='18sp',
            background_color=(0.95, 0.95, 0.95, 1),
            foreground_color=(0, 0, 0, 1)
        )
        layout.add_widget(self.search_input)
        search_btn = Button(
            text='🔍 搜索',
            size_hint=(1, 0.1),
            background_color=(0.2, 0.6, 0.2, 1),
            background_normal='',
            color=(1, 1, 1, 1),
            font_size='20sp',
            bold=True
        )
        search_btn.bind(on_press=self.do_search)
        layout.add_widget(search_btn)
        self.info_label = Label(
            text='正在加载数据...',
            size_hint=(1, 0.08),
            font_size='16sp',
            color=(0.3, 0.3, 0.3, 1)
        )
        layout.add_widget(self.info_label)
        self.result_container = BoxLayout(
            orientation='vertical',
            size_hint_y=None,
            spacing=5,
            padding=[0, 5, 0, 5]
        )
        self.result_container.bind(minimum_height=self.result_container.setter('height'))
        scroll = ScrollView(size_hint=(1, 0.72), bar_width=10, do_scroll_x=False)
        scroll.add_widget(self.result_container)
        layout.add_widget(scroll)
        self.add_widget(layout)
        Clock.schedule_once(self.load_searcher, 0.1)

    def load_searcher(self, dt=None):
        if platform == 'android':
            from android.storage import app_storage_path
            data_dir = app_storage_path()
        else:
            data_dir = os.path.dirname(__file__)
        qa_file = os.path.join(data_dir, 'data', 'qa_pairs.json')
        if not os.path.exists(qa_file):
            qa_file = os.path.join(os.path.dirname(__file__), 'data', 'qa_pairs.json')
        try:
            with open(qa_file, 'r', encoding='utf-8') as f:
                qa_list = json.load(f)
            self.searcher = IntelligentSearcher(qa_list)
            self.info_label.text = f'✅ 已加载 {len(qa_list)} 条问答'
        except Exception as e:
            self.info_label.text = '❌ 加载数据失败'
            print(f'Error: {e}')

    def do_search(self, instance):
        query = self.search_input.text.strip()
        if not query or not self.searcher:
            return
        self.result_container.clear_widgets()
        results = self.searcher.search(query, top_k=15)
        if not results:
            self.result_container.add_widget(Label(
                text='❌ 未找到相关结果',
                size_hint_y=None, height=50,
                color=(0.8, 0.2, 0.2, 1)
            ))
            self.info_label.text = f'搜索: {query} (0条结果)'
            return
        self.result_container.add_widget(Label(
            text=f'✅ 找到 {len(results)} 个结果',
            size_hint_y=None, height=40,
            color=(0, 0.6, 0, 1), bold=True
        ))
        self.info_label.text = f'搜索: {query} ({len(results)}条结果)'
        for res in results:
            btn = Button(
                text=f"[{res['category']}] {res['question'][:40]}...",
                size_hint_y=None, height=70,
                background_normal='',
                background_color=(0.95, 0.95, 0.95, 1),
                color=(0, 0, 0, 1),
                halign='left', valign='middle',
                padding=(15, 0), font_size='15sp'
            )
            btn.bind(on_press=lambda x, r=res: self.show_detail(r))
            self.result_container.add_widget(btn)

    def show_detail(self, result):
        detail = self.manager.get_screen('detail')
        detail.set_result(result)
        self.manager.current = 'detail'

class DetailScreen(Screen):
    question = StringProperty('')
    answer = StringProperty('')
    category = StringProperty('')
    score = StringProperty('')
    keywords = StringProperty('')

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        layout = BoxLayout(orientation='vertical', padding=15, spacing=10)
        back_btn = Button(
            text='← 返回',
            size_hint=(1, 0.08),
            background_color=(0.3, 0.3, 0.3, 1),
            background_normal='',
            color=(1, 1, 1, 1),
            font_size='18sp'
        )
        back_btn.bind(on_press=self.go_back)
        layout.add_widget(back_btn)
        scroll = ScrollView(size_hint=(1, 0.92), bar_width=10)
        content = BoxLayout(orientation='vertical', spacing=15, size_hint_y=None, padding=[0,0,10,10])
        content.bind(minimum_height=content.setter('height'))
        content.add_widget(Label(
            text='[b]问题[/b]', markup=True,
            size_hint_y=None, height=30,
            color=(0.2, 0.6, 0.2, 1),
            font_size='18sp', halign='left'
        ))
        self.question_label = Label(
            text=self.question,
            size_hint_y=None, height=80,
            text_size=(Window.width - 50, None),
            halign='left', valign='top',
            font_size='16sp'
        )
        self.question_label.bind(texture_size=self.question_label.setter('size'))
        content.add_widget(self.question_label)
        content.add_widget(Label(
            text='[b]答案[/b]', markup=True,
            size_hint_y=None, height=30,
            color=(0.2, 0.6, 0.2, 1),
            font_size='18sp', halign='left'
        ))
        self.answer_label = Label(
            text=self.answer,
            size_hint_y=None, height=200,
            text_size=(Window.width - 50, None),
            halign='left', valign='top',
            font_size='16sp'
        )
        self.answer_label.bind(texture_size=self.answer_label.setter('size'))
        content.add_widget(self.answer_label)
        meta = BoxLayout(orientation='horizontal', size_hint_y=None, height=60, spacing=10)
        meta.add_widget(Label(
            text=f'分类: {self.category}',
            size_hint_x=0.5, color=(0.3,0.3,0.3,1), font_size='15sp'
        ))
        meta.add_widget(Label(
            text=f'相似度: {self.score}',
            size_hint_x=0.5, color=(0.3,0.3,0.3,1), font_size='15sp'
        ))
        content.add_widget(meta)
        if self.keywords:
            content.add_widget(Label(
                text=f'关键词: {self.keywords}',
                size_hint_y=None, height=50,
                color=(0.4,0.4,0.4,1),
                font_size='14sp', halign='left'
            ))
        scroll.add_widget(content)
        layout.add_widget(scroll)
        self.add_widget(layout)

    def set_result(self, result):
        self.question = result['question']
        self.answer = result['answer']
        self.category = result['category']
        self.score = str(result['score'])
        self.keywords = result.get('keywords', '')
        self.question_label.text = self.question
        self.answer_label.text = self.answer
        self.question_label.height = max(80, self.question_label.texture_size[1] + 20)
        self.answer_label.height = max(200, self.answer_label.texture_size[1] + 20)

    def go_back(self, instance):
        self.manager.current = 'search'

class SmartKbApp(App):
    def build(self):
        sm = ScreenManager()
        sm.add_widget(SearchScreen(name='search'))
        sm.add_widget(DetailScreen(name='detail'))
        return sm

if __name__ == '__main__':
    SmartKbApp().run()
EOF

# ---------- 4. 创建 buildozer.spec ----------
cat > buildozer.spec << 'EOF'
[app]
title = 智能运维问答系统
package.name = smartkb
package.domain = org.smartkb
source.dir = .
source.include_exts = py,png,jpg,kv,atlas,txt,json
version = 1.0.0
requirements = python3,kivy,jieba
android.permissions = INTERNET, READ_EXTERNAL_STORAGE
android.api = 30
android.minapi = 21
android.ndk = 23c
android.sdk = 30
android.gradle_dependencies = 'com.android.support:support-annotations:28.0.0'
source.include_exts = py,png,jpg,kv,atlas,txt,json
source.include_patterns = data/*.json
android.accept_sdk_license = True

[buildozer]
log_level = 2
EOF

echo "✅ 项目文件已创建完成！"
ls -la
