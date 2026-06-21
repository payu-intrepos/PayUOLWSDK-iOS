#!/usr/bin/env ruby
# frozen_string_literal: true

# Preflight: discover remote tags (read-only git) and print `pod spec cat` for transitive review.
# Usage: ruby scripts/release/preflight.rb [--dry-run]
# VERBOSE=1 for extra debug output (mirrors debugPrint-style tracing).

require 'yaml'
require 'open3'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[preflight] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def load_manifest
  YAML.load_file(MANIFEST)
end

# Returns sorted unique tag strings (best-effort semver-ish: strip refs/tags/, sort reverse lexicographic for simple cases)
def remote_tags(repo_url)
  cmd = ['git', 'ls-remote', '--tags', repo_url]
  debug("running: #{cmd.join(' ')}")
  stdout, stderr, status = Open3.capture3(*cmd)
  unless status.success?
    warn "[preflight] git ls-remote failed for #{repo_url}"
    warn stderr unless stderr.to_s.empty?
    return []
  end
  tags = stdout.each_line.filter_map do |line|
    next if line.include?('refs/tags/') && line.include?('^{}')

    m = line.match(%r{refs/tags/(.+)$})
    next unless m

    t = m[1].strip
    next if t.end_with?('^{}')

    t
  end.uniq
  tags.sort.reverse
end

def print_tag_discovery(manifest)
  section = manifest.dig('preflight', 'git_tag_discovery') || []
  puts '--- Git tag discovery (latest first, best-effort sort) ---'
  section.each do |entry|
    label = entry['label'] || entry['repo_url']
    url = entry['repo_url']
    next unless url

    tags = remote_tags(url)
    puts "\n## #{label}"
    puts "URL: #{url}"
    top = tags.first(15)
    if top.empty?
      puts '(no tags or git failed — check URL / network)'
    else
      top.each { |t| puts "  #{t}" }
      puts "  ... (#{tags.size} total)" if tags.size > 15
    end
  end
end

def print_pod_spec_cat(manifest)
  pods = manifest.dig('preflight', 'pod_spec_cat') || []
  return if pods.empty?

  puts "\n--- pod spec cat (CocoaPods transitive hints) ---"
  pods.each do |pod|
    puts "\n## pod spec cat #{pod}"
    # Array form avoids shell escaping issues with hyphens in pod names.
    stdout, stderr, status = Open3.capture3('pod', 'spec', 'cat', pod)
    out = stdout.to_s
    out += stderr.to_s unless stderr.to_s.empty?
    if !status.success?
      warn "[preflight] pod spec cat #{pod} failed; trying pod trunk info (read-only metadata)"
      stdout2, stderr2, status2 = Open3.capture3('pod', 'trunk', 'info', pod)
      out2 = stdout2.to_s + stderr2.to_s
      if status2.success?
        puts out2
        next
      end
      warn "[preflight] pod trunk info #{pod} also failed."
      puts out.strip.empty? ? '(no output)' : out
      next
    end
    # Print dependency lines only to keep output readable
    dep_lines = out.each_line.select { |l| l =~ /^\s*s\.dependency\b/ || l =~ /^\s*dependency\b/ }
    if dep_lines.empty?
      puts '(no s.dependency lines found — dumping first 40 lines)'
      puts out.each_line.first(40).join
    else
      puts dep_lines.join
    end
  end
end

def main
  dry = ARGV.include?('--dry-run')
  manifest = load_manifest
  debug("loaded manifest: #{MANIFEST}")

  print_tag_discovery(manifest)
  print_pod_spec_cat(manifest)

  puts "\n[preflight] done#{dry ? ' (dry-run: no writes)' : ''}."
end

main
