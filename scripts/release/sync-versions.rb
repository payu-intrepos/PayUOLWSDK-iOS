#!/usr/bin/env ruby
# frozen_string_literal: true

# Syncs versions.yaml -> PayUIndia-*.podspec and Package.swift (SPM pins).
# Debug: set VERBOSE=1 for extra debugPrint-style output.
# Rule: single source of truth (versions.yaml); review `git diff` after run.

require 'yaml'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[sync-versions] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def load_manifest
  unless File.file?(MANIFEST)
    warn "[sync-versions] Missing #{MANIFEST}"
    exit 1
  end
  # Trusted local manifest (this repository). load_file preserves merge keys etc.
  YAML.load_file(MANIFEST)
end

def replace_podspec_version(content, new_version)
  content.sub(/s\.version\s+=\s+"[^"]+"/, %(s.version             = "#{new_version}"))
end

def replace_podspec_dependency(content, pod_name, requirement)
  pattern = /s\.dependency\s+'#{Regexp.escape(pod_name)}',\s*'[^']*'/
  replacement = %(s.dependency            '#{pod_name}', '#{requirement}')
  if content.match?(pattern)
    content.sub(pattern, replacement)
  else
    warn "[sync-version] WARN: no dependency line for #{pod_name} to replace"
    content
  end
end

def write_if_changed(path, new_body)
  old = File.file?(path) ? File.read(path) : nil
  if old == new_body
    debug("unchanged: #{path}")
    return false
  end
  File.write(path, new_body)
  warn "[sync-versions] updated: #{path}"
  true
end

def sync_params(manifest)
  name = 'PayUIndia-OLWParams-SDK'
  path = File.join(ROOT, "#{name}.podspec")
  v = manifest.dig('internal_pods', name)
  raise "internal_pods.#{name} missing" unless v

  body = File.read(path)
  body = replace_podspec_version(body, v)
  write_if_changed(path, body)
end

def sync_core(manifest)
  name = 'PayUIndia-OLWCore-SDK'
  path = File.join(ROOT, "#{name}.podspec")
  internal = manifest['internal_pods'] || {}
  ext = manifest['cocoapods_external'] || {}

  v = internal[name]
  params_v = internal['PayUIndia-OLWParams-SDK']
  raise "internal versions missing for Core" unless v && params_v

  body = File.read(path)
  body = replace_podspec_version(body, v)
  body = replace_podspec_dependency(body, 'PayUIndia-CrashReporter', ext.fetch('PayUIndia-CrashReporter'))
  body = replace_podspec_dependency(body, 'PayUIndia-NetworkReachability', ext.fetch('PayUIndia-NetworkReachability'))
  body = replace_podspec_dependency(body, 'PayUIndia-Analytics', ext.fetch('PayUIndia-Analytics'))
  body = replace_podspec_dependency(body, 'PayUIndia-OLWParams-SDK', params_v)
  write_if_changed(path, body)
end

def sync_ui(manifest)
  name = 'PayUIndia-OLWUI-SDK'
  path = File.join(ROOT, "#{name}.podspec")
  internal = manifest['internal_pods'] || {}
  ext = manifest['cocoapods_external'] || {}

  v = internal[name]
  core_v = internal['PayUIndia-OLWCore-SDK']
  raise "internal versions missing for UI" unless v && core_v

  body = File.read(path)
  body = replace_podspec_version(body, v)
  body = replace_podspec_dependency(body, 'PayUIndia-OLWCore-SDK', core_v)
  body = replace_podspec_dependency(body, 'PayUIndia-Custom-Browser', ext.fetch('PayUIndia-Custom-Browser'))
  body = replace_podspec_dependency(body, 'PayUIndia-DL-SDK', ext.fetch('PayUIndia-DL-SDK'))
  body = replace_podspec_dependency(body, 'PayUIndia-PPI-SDK', ext.fetch('PayUIndia-PPI-SDK'))
  write_if_changed(path, body)
end

def spm_package_line(_package_name, spec)
  url = spec.fetch('url')
  pin = spec.fetch('pin')
  kind = pin.fetch('kind')
  name = spec['spm_name'] # optional override
  # CocoaPods-style name for SPM package() name: must match product package references
  pkg_name = name || _package_name

  case kind
  when 'from'
    ver = pin.fetch('version')
    %(        .package(name: "#{pkg_name}", url: "#{url}", from: "#{ver}"))
  when 'exact'
    ver = pin.fetch('version')
    # swift-tools-version 5.5: PackageDescription accepts string literal for Version in .exact
    %(        .package(name: "#{pkg_name}", url: "#{url}", .exact("#{ver}")))
  when 'revision'
    rev = pin.fetch('value')
    %(        .package(name: "#{pkg_name}", url: "#{url}", revision: "#{rev}"))
  when 'branch'
    br = pin.fetch('branch')
    %(        .package(name: "#{pkg_name}", url: "#{url}", branch: "#{br}"))
  else
    raise "Unknown SPM pin kind: #{kind.inspect} for #{_package_name}"
  end
end

def sync_package_swift(manifest)
  path = File.join(ROOT, 'Package.swift')
  packages = manifest.dig('spm', 'packages') || {}
  raise 'spm.packages missing in versions.yaml' if packages.empty?

  # Preserve order as declared in YAML for stable diffs
  dep_lines = packages.keys.map { |k| spm_package_line(k, packages[k]) }

  marker_begin = '        // BEGIN:GENERATED_SPM_DEPS'
  marker_end = '        // END:GENERATED_SPM_DEPS'

  original = File.read(path)
  unless original.include?(marker_begin) && original.include?(marker_end)
    warn '[sync-versions] Package.swift missing GENERATED_SPM_DEPS markers'
    exit 1
  end

  inner = dep_lines.join(",\n")
  generated_block = [
    marker_begin,
    '        // Generated from versions.yaml — run: ruby scripts/release/sync-versions.rb',
    "#{inner},",
    marker_end
  ].join("\n")

  new_body = original.sub(
    /#{Regexp.escape(marker_begin)}.*?#{Regexp.escape(marker_end)}/m,
    generated_block
  )
  write_if_changed(path, new_body)
end

def sync_release_scripts(manifest)
  internal = manifest['internal_pods'] || {}
  updated = false
  {
    'PayUIndia-OLWParams-SDK-Release.sh' => 'PayUIndia-OLWParams-SDK',
    'PayUIndia-OLWCore-SDK-Release.sh' => 'PayUIndia-OLWCore-SDK',
    'PayUIndia-OLWUI-SDK-Release.sh' => 'PayUIndia-OLWUI-SDK'
  }.each do |filename, pod_key|
    path = File.join(ROOT, filename)
    next unless File.file?(path)

    ver = internal[pod_key]
    next unless ver

    body = File.read(path)
    new_body = body.sub(/^podVersion="[^"]*"/, %(podVersion="#{ver}"))
    updated ||= write_if_changed(path, new_body)
  end
  updated
end

def main
  manifest = load_manifest
  debug("loaded #{MANIFEST}")

  sync_params(manifest)
  sync_core(manifest)
  sync_ui(manifest)
  sync_package_swift(manifest)
  sync_release_scripts(manifest)

  warn '[sync-versions] done.'
end

main
