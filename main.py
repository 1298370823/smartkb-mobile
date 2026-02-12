#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能运维问答系统 - Kivy 移动版
功能：内置问答搜索、详情查看
打包命令：buildozer android debug
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
from kivy.properties import ObjectProperty, StringProperty
from kivy.core.window import Window
from kivy.utils import platform
from kivy.clock import Clock

# 导入核心算法
from smart_kb_core import IntelligentSearcher, TextProcessor

# 设置窗口大小（仅调试模式）
if platform == 'win' or platform == 'linux':
    Window.size = (400, 700)


class SearchScreen(Screen):
    """搜索主界面"""
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.searcher = None
        self.layout = BoxLayout(orientation='vertical', padding=15, spacing=10)

        # 标题
        title = Label(
            text='智能运维问答系统',
            font_size='24sp',
            size_hint=(1, 0.1),
            color=(0.2, 0.7, 0.2, 1),
            bold=True
        )
        self.layout.add_widget(title)

        # 搜索输入框
        self.search_input = TextInput(
            hint_text='输入问题或错误信息...',
            size_hint=(1, 0.1),
            multiline=False,
            font_size='18sp',
            background_color=(0.95, 0.95, 0.95, 1),
            foreground_color=(0, 0, 0, 1)
        )
        self.layout.add_widget(self.search_input)

        # 搜索按钮
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
        self.layout.add_widget(search_btn)

        # 状态提示
        self.info_label = Label(
            text='正在加载数据...',
            size_hint=(1, 0.08),
            font_size='16sp',
            color=(0.3, 0.3, 0.3, 1)
        )
        self.layout.add_widget(self.info_label)

        # 结果列表容器
        self.result_container = BoxLayout(
            orientation='vertical',
            size_hint_y=None,
            spacing=5,
            padding=[0, 5, 0, 5]
        )
        self.result_container.bind(minimum_height=self.result_container.setter('height'))

        scroll = ScrollView(
            size_hint=(1, 0.72),
            bar_width=10,
            do_scroll_x=False
        )
        scroll.add_widget(self.result_container)
        self.layout.add_widget(scroll)

        self.add_widget(self.layout)

        # 延迟加载数据（界面优先渲染）
        Clock.schedule_once(self.load_searcher, 0.1)

    def load_searcher(self, dt=None):
        """加载问答数据"""
        # 确定数据文件路径（兼容 APK 内部存储）
        if platform == 'android':
            from android.storage import app_storage_path
            data_dir = app_storage_path()
        else:
            data_dir = os.path.dirname(__file__)

        qa_file = os.path.join(data_dir, 'data', 'qa_pairs.json')
        if not os.path.exists(qa_file):
            # 尝试从当前目录查找
            qa_file = os.path.join(os.path.dirname(__file__), 'data', 'qa_pairs.json')

        try:
            with open(qa_file, 'r', encoding='utf-8') as f:
                qa_list = json.load(f)
            self.searcher = IntelligentSearcher(qa_list)
            self.info_label.text = f'✅ 已加载 {len(qa_list)} 条问答'
        except Exception as e:
            self.info_label.text = '❌ 加载数据失败，请检查文件'
            print(f'Error loading qa data: {e}')

    def do_search(self, instance):
        """执行搜索"""
        query = self.search_input.text.strip()
        if not query:
            return
        if not self.searcher:
            self.info_label.text = '搜索引擎未就绪'
            return

        # 清空旧结果
        self.result_container.clear_widgets()

        # 执行搜索
        results = self.searcher.search(query, top_k=15)

        if not results:
            self.result_container.add_widget(
                Label(
                    text='❌ 未找到相关结果',
                    size_hint_y=None,
                    height=50,
                    color=(0.8, 0.2, 0.2, 1)
                )
            )
            self.info_label.text = f'搜索: {query} (0条结果)'
            return

        # 显示结果数量
        count_label = Label(
            text=f'✅ 找到 {len(results)} 个结果',
            size_hint_y=None,
            height=40,
            color=(0, 0.6, 0, 1),
            bold=True
        )
        self.result_container.add_widget(count_label)
        self.info_label.text = f'搜索: {query} ({len(results)}条结果)'

        # 逐个添加结果项
        for res in results:
            item = self.create_result_item(res)
            self.result_container.add_widget(item)

    def create_result_item(self, result):
        """创建一个结果项"""
        # 截断问题标题
        q_text = result['question']
        if len(q_text) > 40:
            q_text = q_text[:40] + '...'

        btn = Button(
            text=f"[{result['category']}] {q_text}",
            size_hint_y=None,
            height=70,
            background_normal='',
            background_color=(0.95, 0.95, 0.95, 1),
            color=(0, 0, 0, 1),
            halign='left',
            valign='middle',
            padding=(15, 0),
            font_size='15sp'
        )
        # 绑定点击事件
        btn.bind(on_press=lambda x, r=result: self.show_detail(r))
        return btn

    def show_detail(self, result):
        """跳转到详情页"""
        detail_screen = self.manager.get_screen('detail')
        detail_screen.set_result(result)
        self.manager.current = 'detail'


class DetailScreen(Screen):
    """详情界面"""
    question = StringProperty('')
    answer = StringProperty('')
    category = StringProperty('')
    score = StringProperty('')
    keywords = StringProperty('')

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=15, spacing=10)

        # 返回按钮
        back_btn = Button(
            text='← 返回',
            size_hint=(1, 0.08),
            background_color=(0.3, 0.3, 0.3, 1),
            background_normal='',
            color=(1, 1, 1, 1),
            font_size='18sp'
        )
        back_btn.bind(on_press=self.go_back)
        self.layout.add_widget(back_btn)

        # 滚动内容区
        scroll = ScrollView(
            size_hint=(1, 0.92),
            bar_width=10
        )
        content = BoxLayout(
            orientation='vertical',
            spacing=15,
            size_hint_y=None,
            padding=[0, 0, 10, 10]
        )
        content.bind(minimum_height=content.setter('height'))

        # 问题标题
        content.add_widget(Label(
            text='[b]问题[/b]',
            markup=True,
            size_hint_y=None,
            height=30,
            color=(0.2, 0.6, 0.2, 1),
            font_size='18sp',
            halign='left'
        ))
        self.question_label = Label(
            text=self.question,
            size_hint_y=None,
            height=80,
            text_size=(Window.width - 50, None),
            halign='left',
            valign='top',
            font_size='16sp'
        )
        self.question_label.bind(texture_size=self.question_label.setter('size'))
        content.add_widget(self.question_label)

        # 答案内容
        content.add_widget(Label(
            text='[b]答案[/b]',
            markup=True,
            size_hint_y=None,
            height=30,
            color=(0.2, 0.6, 0.2, 1),
            font_size='18sp',
            halign='left'
        ))
        self.answer_label = Label(
            text=self.answer,
            size_hint_y=None,
            height=200,
            text_size=(Window.width - 50, None),
            halign='left',
            valign='top',
            font_size='16sp'
        )
        self.answer_label.bind(texture_size=self.answer_label.setter('size'))
        content.add_widget(self.answer_label)

        # 元信息
        meta = BoxLayout(orientation='horizontal', size_hint_y=None, height=60, spacing=10)
        meta.add_widget(Label(
            text=f'分类: {self.category}',
            size_hint_x=0.5,
            color=(0.3, 0.3, 0.3, 1),
            font_size='15sp'
        ))
        meta.add_widget(Label(
            text=f'相似度: {self.score}',
            size_hint_x=0.5,
            color=(0.3, 0.3, 0.3, 1),
            font_size='15sp'
        ))
        content.add_widget(meta)

        # 关键词
        if self.keywords:
            content.add_widget(Label(
                text=f'关键词: {self.keywords}',
                size_hint_y=None,
                height=50,
                color=(0.4, 0.4, 0.4, 1),
                font_size='14sp',
                halign='left'
            ))

        scroll.add_widget(content)
        self.layout.add_widget(scroll)
        self.add_widget(self.layout)

    def set_result(self, result):
        """设置详情数据"""
        self.question = result['question']
        self.answer = result['answer']
        self.category = result['category']
        self.score = str(result['score'])
        self.keywords = result.get('keywords', '')

        self.question_label.text = self.question
        self.answer_label.text = self.answer

        # 动态调整高度
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

    def on_start(self):
        """应用启动后执行"""
        pass


if __name__ == '__main__':
    SmartKbApp().run()