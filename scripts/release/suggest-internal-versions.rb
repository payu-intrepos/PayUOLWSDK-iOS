#!/usr/bin/env ruby
# frozen_string_literal: true

# Uses git ls-remote on metadata.git_source_url + simple alpha prerelease bump to suggest next internal_pods versions.
# Does not write versions.yaml — review and paste. Debug: VERBOSE=1
#
# Usage:
#   ruby scripts/release/suggest-internal-versions.rb

require 'yaml'
require 'open3'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[suggest-internal-versions] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

# Bump x.y.z.alpha.N -> x.y.z.alpha.(N+1). Other patterns: returns nil (edit manually).
def bump_alpha_prerelease(version)
  s = version.to_s
  return nil unless (m = s.match(/\A(\d+\.\d+\.\d+\.alpha\.)(\d+)\z/))

  "#{m[1]}#{m[2].to_i + 1}"
end

def remote_tags(repo_url)
  cmd = ['git', 'ls-remote', '--tags', repo_url]
  debug("running: #{cmd.join(' ')}")
  stdout, stderr, status = Open3.capture3(*cmd)
  unless status.success?
    warn "[suggest-internal-versions] git ls-remote failed: #{stderr.strip[0, 300]}"
    return []
  end

  stdout.each_line.filter_map do |line|
    next if line.include?('refs/tags/') && line.include?('^{}')

    m = line.match(%r{refs/tags/(.+)$})
    next unless m

    t = m[1].strip
    next if t.end_with?('^{}')

    t.sub(/\Av/, '')
  end.uniq
end

def safe_gem_version(s)
  Gem::Version.new(s)
rescue ArgumentError
  nil
end

def main
  unless File.file?(MANIFEST)
    warn "[suggest-internal-versions] missing #{MANIFEST}"
    exit 2
  end

  m = YAML.load_file(MANIFEST)
  url = m.dig('metadata', 'git_source_url')
  internal = m['internal_pods'] || {}

  if url.to_s.empty?
    warn '[suggest-internal-versions] metadata.git_source_url missing; cannot query remote tags.'
    exit 2
  end

  tags = remote_tags(url)
  parsed = tags.filter_map { |t| safe_gem_version(t) }
  remote_max = parsed.max
  remote_max_s = remote_max&.to_s

  puts '=== suggest-internal-versions ==='
  puts "git_source_url: #{url}"
  puts "Remote tags (sample, newest-first lex sort): #{tags.sort.reverse.first(8).join(', ')}"
  puts "Remote max (Gem::Version, parseable only): #{remote_max_s || '(none)'}"
  puts

  puts 'Per-pod: current (yaml) | bump-alpha(current) | note'
  internal.each do |pod, ver|
    nxt = bump_alpha_prerelease(ver)
    gv = safe_gem_version(ver)
    note = []
    note << 'cannot auto-bump pattern (edit versions.yaml manually)' if nxt.nil?
    if remote_max && gv && remote_max >= gv
      note << "remote already has tags >= #{ver} — ensure your next tag is new on GitHub"
    end
    puts "  #{pod}: #{ver} | #{nxt || '—'} | #{note.join('; ')}"
  end

  puts
  puts 'Paste candidate (adjust per your policy):'
  puts 'internal_pods:'
  internal.each_key do |pod|
    ver = internal[pod]
    nxt = bump_alpha_prerelease(ver) || ver
    puts "  #{pod}: \"#{nxt}\""
  end
  puts
  puts '[suggest-internal-versions] done (no files written).'
end

main
