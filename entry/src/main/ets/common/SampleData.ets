import { Course } from './types';

/** 首次启动的示例课表数据（数据库为空时自动插入） */
export function sampleCourses(): Course[] {
  const list: Course[] = [];
  list.push({
    name: '高等数学（三）',
    teacher: '张伟明',
    room: '明 3-102',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 0,
    priority: 1,
    content: '多元函数微分学、重积分与曲线曲面积分，期末闭卷考试占比 60%。'
  });
  list.push({
    name: '大学英语（四）',
    teacher: '李静',
    room: '文 2-201',
    dayOfWeek: 1,
    startSection: 3,
    endSection: 4,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 3,
    priority: 0,
    content: '听说读写综合训练，每单元配套口语展示，注意四级词汇积累。'
  });
  list.push({
    name: '数据结构',
    teacher: '王强',
    room: '明 1-301',
    dayOfWeek: 1,
    startSection: 6,
    endSection: 7,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 1,
    priority: 2,
    content: '线性表、栈与队列、树与二叉树、图、查找与排序，含三次上机实验。'
  });
  list.push({
    name: '操作系统',
    teacher: '赵磊',
    room: '明 2-203',
    dayOfWeek: 2,
    startSection: 1,
    endSection: 2,
    weekType: 0,
    startWeek: 1,
    endWeek: 15,
    colorIndex: 2,
    priority: 2,
    content: '进程与线程、内存管理、文件系统与 IO，期末有课程设计报告。'
  });
  list.push({
    name: '线性代数',
    teacher: '刘芳',
    room: '明 3-102',
    dayOfWeek: 2,
    startSection: 3,
    endSection: 4,
    weekType: 1,
    startWeek: 3,
    endWeek: 13,
    colorIndex: 4,
    priority: 0,
    content: '矩阵运算、行列式、向量组与二次型，单周上课。'
  });
  list.push({
    name: '大学物理实验',
    teacher: '吴敏',
    room: '实 2-301',
    dayOfWeek: 2,
    startSection: 6,
    endSection: 8,
    weekType: 2,
    startWeek: 5,
    endWeek: 14,
    colorIndex: 6,
    priority: 1,
    content: '双周实验课，需提前写预习报告，实验结束当堂提交数据。'
  });
  list.push({
    name: '体育（三）',
    teacher: '陈刚',
    room: '体育馆',
    dayOfWeek: 2,
    startSection: 8,
    endSection: 9,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 7,
    priority: 0,
    content: '篮球选项课，穿运动鞋，缺勤三次取消考试资格。'
  });
  list.push({
    name: '计算机组成原理',
    teacher: '孙明',
    room: '明 1-402',
    dayOfWeek: 3,
    startSection: 1,
    endSection: 2,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 1,
    priority: 1,
    content: '运算器、存储器、指令系统与 CPU 结构，配套 Logisim 仿真作业。'
  });
  list.push({
    name: '概率论与数理统计',
    teacher: '周华',
    room: '明 3-103',
    dayOfWeek: 3,
    startSection: 6,
    endSection: 7,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 0,
    priority: 0,
    content: '随机变量、数字特征、参数估计与假设检验。'
  });
  list.push({
    name: '算法设计与分析',
    teacher: '郑洁',
    room: '明 2-105',
    dayOfWeek: 4,
    startSection: 1,
    endSection: 2,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 2,
    priority: 2,
    content: '分治、贪心、动态规划、回溯与分支限界，每周一次 OJ 作业。'
  });
  list.push({
    name: '毛泽东思想和中国特色社会主义理论体系概论',
    teacher: '钱进',
    room: '文 4-201',
    dayOfWeek: 4,
    startSection: 6,
    endSection: 7,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 3,
    priority: 0,
    content: '理论讲授结合小组展示，期末论文占总评 40%。'
  });
  list.push({
    name: '数据库原理',
    teacher: '冯涛',
    room: '明 2-207',
    dayOfWeek: 5,
    startSection: 3,
    endSection: 4,
    weekType: 0,
    startWeek: 1,
    endWeek: 16,
    colorIndex: 4,
    priority: 1,
    content: '关系模型、SQL、范式与事务，期末设计一个小型数据库应用。'
  });
  list.push({
    name: '形势与政策',
    teacher: '何军',
    room: '文 4-103',
    dayOfWeek: 5,
    startSection: 8,
    endSection: 9,
    weekType: 0,
    startWeek: 5,
    endWeek: 12,
    colorIndex: 5,
    priority: 0,
    content: '专题讲座形式，按学院安排出席并提交学习心得。'
  });
  return list;
}
