# -*- coding: utf-8 -*-
"""
智能运维知识库核心算法（移动版）
- 纯 Python 实现，无 scikit-learn 依赖
- 保留 jieba 分词、SequenceMatcher 相似度
- 适用于 Kivy 移动应用
"""

import json
import re
from collections import Counter
from difflib import SequenceMatcher
from typing import List, Dict, Optional, Tuple

# 尝试导入 jieba（移动端需打包）
try:
    import jieba
    HAS_JIEBA = True
except ImportError:
    HAS_JIEBA = False

# ==================== 文本处理器 ====================
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
        """中文分词（支持 jieba 降级）"""
        if not text:
            return []
        if HAS_JIEBA:
            try:
                return list(jieba.cut(text))
            except:
                pass
        # 简单分词（按字符）
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
        """提取关键词"""
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
        """文本相似度"""
        if not t1 or not t2:
            return 0.0
        return SequenceMatcher(None, t1.lower(), t2.lower()).ratio()


# ==================== 问题分类器 ====================
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


# ==================== 智能搜索引擎 ====================
class IntelligentSearcher:
    def __init__(self, qa_pairs: List[Dict]):
        self.qa_pairs = qa_pairs
        # 为每个问题建立关键词索引
        self.index = []
        for qa in qa_pairs:
            text = f"{qa['question']} {qa['answer']} {qa.get('keywords', '')}".lower()
            self.index.append(text)

    def search(self, query: str, top_k: int = 10, min_score: float = 0.1) -> List[Dict]:
        """搜索相关问题（基于关键词 + 相似度）"""
        if not self.qa_pairs:
            return []
        ql = query.lower()
        qkws = TextProcessor.extract_keywords(query)

        scores = []
        for idx, qa in enumerate(self.qa_pairs):
            score = 0.0
            ql_ques = qa['question'].lower()

            # 1. 精确包含查询词
            if ql in ql_ques:
                score += 0.5
            if ql in qa['answer'].lower():
                score += 0.3

            # 2. 关键词匹配
            for kw in qkws:
                if kw in ql_ques or kw in qa['answer'].lower() or kw in qa.get('keywords', '').lower():
                    score += 0.2

            # 3. 错误模式匹配
            errs = self._extract_error_patterns(query)
            for e in errs:
                if e in ql_ques or e in qa['answer'].lower():
                    score += 0.4

            # 4. 许可证相关加分
            if any(w in ql for w in ['license', '许可证', '授权', '过期']) and qa.get('category') == '许可证授权':
                score += 0.6

            # 5. 答案长度加分（详细答案更好）
            if len(qa['answer']) > 500:
                score += 0.2
            elif len(qa['answer']) > 200:
                score += 0.1

            if score > min_score:
                scores.append((idx, score))

        # 按得分排序
        scores.sort(key=lambda x: x[1], reverse=True)

        # 构造返回结果
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
        """提取错误模式"""
        pats = re.findall(r'([A-Z][a-zA-Z]*Exception|Error|Failure|Timeout)', text)
        pats += re.findall(r'[A-Z]{2,}_?\d{3,}|[A-Z]+-\d+', text)
        pats += re.findall(r'license|License|LICENSE|许可证|授权|过期|到期', text, re.IGNORECASE)
        return list(set(pats))

    def _generate_highlight(self, query: str, qa: Dict) -> str:
        """生成高亮摘要"""
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