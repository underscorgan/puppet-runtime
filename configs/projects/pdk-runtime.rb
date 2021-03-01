project 'pdk-runtime' do |proj|
  platform = proj.get_platform
  runtime_details = JSON.parse(File.read('configs/components/ruby-runtime.json'))

  settings[:puppet_runtime_version] = runtime_details['version']
  settings[:puppet_runtime_location] = runtime_details['location']
  settings[:puppet_runtime_basename] = "ruby-runtime-#{runtime_details['version']}.#{platform.name}"

  settings_uri = File.join(runtime_details['location'], "#{proj.settings[:puppet_runtime_basename]}.settings.yaml")
  metadata_uri = File.join(runtime_details['location'], "#{proj.settings[:puppet_runtime_basename]}.json")
  sha1sum_uri = "#{settings_uri}.sha1"
  proj.inherit_yaml_settings(settings_uri, sha1sum_uri, metadata_uri: metadata_uri)

  # Used in component configurations to conditionally include dependencies
  proj.setting(:runtime_project, "pdk")

  proj.version_from_git
  proj.generate_archives true
  proj.generate_packages false

  proj.description "The PDK runtime contains third-party components needed for the puppet developer kit"
  proj.license "See components"
  proj.vendor "Puppet, Inc.  <info@puppet.com>"
  proj.homepage "https://puppet.com"

  if platform.is_macos?
    proj.identifier "com.puppetlabs"
  end

  # Common deps
  # proj.component "openssl-#{proj.openssl_version}"
  proj.component "ruby-runtime"
  proj.component "curl"

  # Git and deps
  proj.component "git"

  # Ruby and deps
  #proj.component "runtime-pdk"
  #proj.component "puppet-ca-bundle"

  proj.component "augeas" unless platform.is_windows?
  proj.component "libxml2" unless platform.is_windows?
  proj.component "libxslt" unless platform.is_windows?

  #proj.component "ruby-#{proj.ruby_version}"

  proj.component "ruby-augeas" unless platform.is_windows?

  # We only build ruby-selinux for EL 5-7
  if platform.is_el? || platform.is_fedora?
    proj.component "ruby-selinux"
  end

  proj.component "ruby-stomp"

  # PDK Rubygems
  proj.component "rubygem-ffi"
  proj.component "rubygem-locale"
  proj.component "rubygem-text"
  proj.component "rubygem-gettext"
  proj.component "rubygem-fast_gettext"
  proj.component "rubygem-gettext-setup"
  proj.component "rubygem-minitar"

  # Additional Rubies
  if settings[:additional_rubies]
    settings[:additional_rubies].keys.each do |rubyver|
      #proj.component "ruby-#{rubyver}"

      ruby_minor = rubyver.split('.')[0,2].join('.')

      proj.component "ruby-#{ruby_minor}-augeas" unless platform.is_windows?
      proj.component "ruby-#{ruby_minor}-selinux" if platform.is_el? || platform.is_fedora?
      proj.component "ruby-#{ruby_minor}-stomp"
    end
  end

  # Platform specific deps
  proj.component "ansicon" if platform.is_windows?

  # What to include in package?
  proj.directory proj.install_root
  proj.directory proj.prefix
  proj.directory proj.link_bindir unless platform.is_windows?

  # Export the settings for the current project and platform as yaml during builds
  proj.publish_yaml_settings

  proj.timeout 7200 if platform.is_windows?

  # Here we rewrite public http urls to use our internal source host instead.
  # Something like https://www.openssl.org/source/openssl-1.0.0r.tar.gz gets
  # rewritten as
  # https://artifactory.delivery.puppetlabs.net/artifactory/generic/buildsources/openssl-1.0.0r.tar.gz
  proj.register_rewrite_rule 'http', proj.buildsources_url
end
