#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "open3"
require "pathname"
require "rbconfig"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
REQUIRED_FIELDS = %w[
  layout title slug lesson stage stage_description description takeaway
  beginner_question beginner_analogy beginner_skip image tags read_time status
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def png_dimensions(path)
  header = File.binread(path, 24)
  fail_check("#{path} is not a valid PNG") unless header.start_with?("\x89PNG\r\n\x1A\n".b)

  header.unpack("@16NN")
end

def markdown_image_targets(markdown)
  markdown.scan(/!\[[^\]]*\]\(([^)]+)\)/).map do |match|
    raw_target = match.first.strip
    if raw_target.start_with?("<")
      raw_target[/\A<([^>]+)>/, 1]
    else
      raw_target.split(/\s+/, 2).first
    end
  end.compact
end

posts = Dir[ROOT.join("_posts/*.md")].map do |file|
  text = File.read(file)
  match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
  fail_check("invalid front matter: #{file}") unless match

  data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true)
  body = match[2]
  missing = REQUIRED_FIELDS.reject { |field| data.key?(field) }
  fail_check("#{file} missing fields: #{missing.join(', ')}") unless missing.empty?
  fail_check("#{file} needs a 本课用词 block") unless body.include?("**本课用词**")
  fail_check("#{file} needs at least three main sections") if body.scan(/^## /).size < 3
  fail_check("#{file} is too short for a detailed lesson") if body.length < 1_500
  {
    "beginner_question" => 55,
    "beginner_analogy" => 90,
    "beginner_skip" => 55
  }.each do |field, max_length|
    value = data.fetch(field).to_s.strip
    fail_check("#{file} has an empty #{field}") if value.empty?
    fail_check("#{file} #{field} is too long (#{value.length} > #{max_length})") if value.length > max_length
  end
  if data.fetch("lesson") >= 36
    fail_check("#{file} needs at least six main sections") if body.scan(/^## /).size < 6
    fail_check("#{file} needs a lesson-specific exercise") unless body.match?(/^## .*练习/)
  end

  image = ROOT.join(data.fetch("image").sub(%r{^/}, ""))
  fail_check("missing image: #{image}") unless image.file?
  width, height = png_dimensions(image)
  ratio_error = ((width.to_f / height) - (16.0 / 9)).abs
  fail_check("#{image} is #{width}x#{height}, expected 16:9") if ratio_error > 0.02

  {
    file: file,
    data: data,
    body: body,
    image: image.cleanpath,
    image_sha256: Digest::SHA256.file(image).hexdigest
  }
end.sort_by { |post| post[:data].fetch("lesson") }

fail_check("no course posts found") if posts.empty?

lessons = posts.map { |post| post[:data].fetch("lesson") }
expected_lessons = (lessons.first..lessons.last).to_a
fail_check("lesson numbers are not continuous: #{lessons.inspect}") unless lessons == expected_lessons
fail_check("expected exactly 54 lessons (1-54), got: #{lessons.inspect}") unless lessons == (1..54).to_a

slugs = posts.map { |post| post[:data].fetch("slug") }
fail_check("lesson slugs are not unique") unless slugs.uniq.size == slugs.size

posts.each_with_index do |post, index|
  data = post[:data]
  expected_prev = index.zero? ? nil : posts[index - 1][:data].fetch("slug")
  expected_next = index == posts.size - 1 ? nil : posts[index + 1][:data].fetch("slug")
  fail_check("bad prev_slug in #{post[:file]}") unless data["prev_slug"] == expected_prev
  fail_check("bad next_slug in #{post[:file]}") unless data["next_slug"] == expected_next
end

%w[README.md about.md evidence.md glossary.md].each do |document|
  path = ROOT.join(document)
  fail_check("missing reader document: #{document}") unless path.file?
  fail_check("empty reader document: #{document}") if path.size.zero?
end

artifact_failures = []

duplicate_image_groups = posts.group_by { |post| post[:image_sha256] }
                              .select { |_sha256, group| group.size > 1 }
duplicate_image_groups.each do |sha256, group|
  lesson_list = group.map { |post| format("%02d", post[:data].fetch("lesson")) }.join(", ")
  image_list = group.map { |post| post[:image].relative_path_from(ROOT) }.join(", ")
  artifact_failures << "duplicate course image SHA-256 #{sha256}: lessons #{lesson_list} (#{image_list})"
end

missing_readmes = []
incomplete_readmes = []
missing_local_image_references = []
sync_script = ROOT.join("scripts/sync_lesson_readmes.rb")

posts.each do |post|
  lesson = post[:data].fetch("lesson")
  lesson_directory = ROOT.join(format("lesson%02d", lesson)).cleanpath
  readme = lesson_directory.join("README.md")

  unless readme.file?
    missing_readmes << format("lesson%02d/README.md", lesson)
    next
  end

  readme_text = File.read(readme)
  if !sync_script.file? && !readme_text.include?(post[:body].strip)
    incomplete_readmes << format("lesson%02d/README.md", lesson)
  end

  references_frontmatter_image = markdown_image_targets(readme_text).any? do |target|
    next false if target.start_with?("/", "http://", "https://", "data:")

    target_without_suffix = target.split(/[?#]/, 2).first
    referenced_image = lesson_directory.join(target_without_suffix).cleanpath
    referenced_image.dirname == lesson_directory && referenced_image == post[:image] && referenced_image.file?
  end
  missing_local_image_references << format("lesson%02d/README.md", lesson) unless references_frontmatter_image
end

artifact_failures << "missing per-lesson README files: #{missing_readmes.join(', ')}" unless missing_readmes.empty?
unless incomplete_readmes.empty?
  artifact_failures << "README files do not contain the complete lesson body: #{incomplete_readmes.join(', ')}"
end
unless missing_local_image_references.empty?
  artifact_failures << "README files must reference their frontmatter image from the same directory: #{missing_local_image_references.join(', ')}"
end

if sync_script.file?
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, sync_script.to_s, "--check", chdir: ROOT.to_s)
  unless status.success?
    sync_output = [stdout, stderr].reject(&:empty?).join("\n").strip
    artifact_failures << "lesson README synchronization check failed#{sync_output.empty? ? '' : ": #{sync_output}"}"
  end
end

fail_check("course artifact regressions:\n- #{artifact_failures.join("\n- ")}") unless artifact_failures.empty?

puts "PASS: #{posts.size} lessons (#{lessons.first}-#{lessons.last})"
puts "PASS: metadata, terminology blocks, sections, navigation and 16:9 images"
puts "PASS: detailed-lesson length, advanced-section depth and exercises"
puts "PASS: concise zero-background questions, analogies and skip guidance"
puts "PASS: README, about, evidence and glossary entry points"
puts "PASS: 54 unique course-image SHA-256 digests"
puts "PASS: per-lesson README files, complete lesson bodies and same-directory images"
