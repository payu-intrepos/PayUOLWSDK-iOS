#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints shell `export` lines for GIT_AUTHOR_* / GIT_COMMITTER_* from versions.yaml → release.git_author.
# Skips any variable already set in the environment (caller wins).
# Debug: VERBOSE=1
#
# Usage (from bash):
#   eval "$(ruby scripts/release/git-author-from-manifest.rb)"

require 'yaml'
require 'shellwords'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[git-author-from-manifest] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def main
  return if ENV['GIT_AUTHOR_EMAIL'].to_s.strip != ''

  unless File.file?(MANIFEST)
    debug("no #{MANIFEST}")
    return
  end

  m = YAML.load_file(MANIFEST)
  ga = m.dig('release', 'git_author')
  return unless ga.is_a?(Hash)

  name = ga['name'].to_s.strip
  email = ga['email'].to_s.strip
  return if name.empty? || email.empty?

  qn = Shellwords.shellescape(name)
  qe = Shellwords.shellescape(email)
  puts %(export GIT_AUTHOR_NAME=#{qn})
  puts %(export GIT_AUTHOR_EMAIL=#{qe})
  puts %(export GIT_COMMITTER_NAME=#{qn})
  puts %(export GIT_COMMITTER_EMAIL=#{qe})
  debug('exported release.git_author into environment')
end

main
