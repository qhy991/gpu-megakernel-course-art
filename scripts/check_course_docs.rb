#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "pathname"
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

  { file: file, data: data, body: body }
end.sort_by { |post| post[:data].fetch("lesson") }

fail_check("no course posts found") if posts.empty?

lessons = posts.map { |post| post[:data].fetch("lesson") }
expected_lessons = (lessons.first..lessons.last).to_a
fail_check("lesson numbers are not continuous: #{lessons.inspect}") unless lessons == expected_lessons

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

puts "PASS: #{posts.size} lessons (#{lessons.first}-#{lessons.last})"
puts "PASS: metadata, terminology blocks, sections, navigation and 16:9 images"
puts "PASS: detailed-lesson length, advanced-section depth and exercises"
puts "PASS: concise zero-background questions, analogies and skip guidance"
puts "PASS: README, about, evidence and glossary entry points"
