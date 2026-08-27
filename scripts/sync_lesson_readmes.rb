#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
POSTS_DIR = ROOT.join("_posts")
CONFIG_PATH = ROOT.join("_config.yml")
EXPECTED_LESSONS = (1..54).to_a.freeze
GENERATED_NOTICE = <<~NOTICE.chomp.freeze
  <!--
  本文由 scripts/sync_lesson_readmes.rb 从对应的 _posts 文章确定性生成。
  请编辑课程原文后重新运行同步脚本，不要单独修改本文件。
  -->
NOTICE

def abort_with(message)
  warn "FAIL: #{message}"
  exit 1
end

def load_yaml(text, source)
  YAML.safe_load(text, permitted_classes: [Date, Time], aliases: true) || {}
rescue Psych::Exception => error
  abort_with("cannot parse YAML in #{source}: #{error.message}")
end

def parse_post(path)
  text = path.read
  match = text.match(/\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z/m)
  abort_with("invalid front matter: #{path.relative_path_from(ROOT)}") unless match

  data = load_yaml(match[1], path.relative_path_from(ROOT))
  required = %w[
    title slug lesson description takeaway beginner_question beginner_analogy
    beginner_skip image status
  ]
  missing = required.reject { |field| data.key?(field) }
  abort_with("#{path.relative_path_from(ROOT)} missing fields: #{missing.join(', ')}") unless missing.empty?

  lesson = Integer(data.fetch("lesson"))
  {
    path: path,
    data: data,
    body: match[2].sub(/\A\r?\n/, "").rstrip,
    lesson: lesson,
    directory: format("lesson%02d", lesson)
  }
rescue ArgumentError, TypeError
  abort_with("#{path.relative_path_from(ROOT)} has an invalid lesson number")
end

def site_root
  config = load_yaml(CONFIG_PATH.read, CONFIG_PATH.relative_path_from(ROOT))
  url = config.fetch("url").to_s.sub(%r{/+\z}, "")
  baseurl = config.fetch("baseurl", "").to_s
  baseurl = "/#{baseurl}" unless baseurl.empty? || baseurl.start_with?("/")
  "#{url}#{baseurl.sub(%r{/+\z}, '')}"
end

def navigation_item(prefix, post, suffix = "")
  title = post.fetch(:data).fetch("title")
  "- [#{prefix}第 #{post.fetch(:lesson)} 课：#{title}#{suffix}](../#{post.fetch(:directory)}/)"
end

def render_readme(post, previous_post, next_post, root_url)
  data = post.fetch(:data)
  lesson = post.fetch(:lesson)
  title = data.fetch("title")
  source_image = data.fetch("image").to_s.sub(%r{\A/+}, "")
  expected_directory = post.fetch(:directory)
  unless File.dirname(source_image) == expected_directory
    abort_with("#{post.fetch(:path).relative_path_from(ROOT)} image is not in #{expected_directory}")
  end

  image_name = File.basename(source_image)
  image_path = ROOT.join(expected_directory, image_name)
  abort_with("missing lesson image: #{image_path.relative_path_from(ROOT)}") unless image_path.file?

  navigation = []
  navigation << "- [在线阅读本课](#{root_url}/lessons/#{data.fetch('slug')}/)"
  navigation << navigation_item("← 上一课 · ", previous_post) if previous_post
  navigation << navigation_item("下一课 · ", next_post, " →") if next_post

  <<~MARKDOWN
    #{GENERATED_NOTICE}

    # 第 #{lesson} 课｜#{title}

    ![第 #{lesson} 课：#{title}](./#{image_name})

    > #{data.fetch("description")}

    ## 零基础先看这里

    - **它在解决什么：**#{data.fetch("beginner_question")}
    - **把它想成：**#{data.fetch("beginner_analogy")}
    - **这次先不用懂：**#{data.fetch("beginner_skip")}

    ## 本课结论与证据状态

    - **一句话结论：**#{data.fetch("takeaway")}
    - **证据状态：**#{data.fetch("status")}
    - **怎么看这个标签：**它表示结论的来源与适用范围，不是课程难度；可查看[中文证据规则](../evidence.md)。

    ## 完整课程正文

    #{post.fetch(:body)}

    ## 读完自检

    1. 先不看上文，用自己的话回答：#{data.fetch("beginner_question")}
    2. 再对照本课结论：#{data.fetch("takeaway")}
    3. 根据 `#{data.fetch("status")}`，说出这条结论能证明什么、不能外推什么。

    ## 继续学习

    #{navigation.join("\n")}
  MARKDOWN
end

unless ARGV.empty? || ARGV == ["--check"]
  warn "Usage: ruby scripts/sync_lesson_readmes.rb [--check]"
  exit 2
end

check_mode = ARGV == ["--check"]
posts = Dir[POSTS_DIR.join("*.md")].sort.map { |file| parse_post(Pathname.new(file)) }
posts.sort_by! { |post| post.fetch(:lesson) }

lessons = posts.map { |post| post.fetch(:lesson) }
abort_with("expected lessons 1-54, found #{lessons.inspect}") unless lessons == EXPECTED_LESSONS
abort_with("lesson slugs are not unique") unless posts.map { |post| post.fetch(:data).fetch("slug") }.uniq.size == posts.size

root_url = site_root
mismatches = []

posts.each_with_index do |post, index|
  previous_post = index.zero? ? nil : posts[index - 1]
  expected = render_readme(post, previous_post, posts[index + 1], root_url)
  target = ROOT.join(post.fetch(:directory), "README.md")

  if check_mode
    mismatches << target.relative_path_from(ROOT).to_s unless target.file? && target.read == expected
  else
    target.dirname.mkpath
    target.write(expected)
  end
end

if check_mode
  abort_with("lesson README files are missing or out of sync: #{mismatches.join(', ')}") unless mismatches.empty?
  puts "PASS: 54 lesson README files exactly match their _posts sources"
else
  puts "WROTE: 54 lesson README files from _posts"
end
