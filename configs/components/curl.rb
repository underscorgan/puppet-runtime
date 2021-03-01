component 'curl' do |pkg, settings, platform|
  pkg.version '7.74.0'
  pkg.sha256sum 'e56b3921eeb7a2951959c02db0912b5fcd5fdba5aca071da819e1accf338bbd7'
  pkg.url "https://curl.haxx.se/download/curl-#{pkg.get_version}.tar.gz"
  pkg.mirror "#{settings[:buildsources_url]}/curl-#{pkg.get_version}.tar.gz"

  if platform.is_aix?
    # Patch to disable _ALL_SOURCE when including select.h from multi.c. See patch for details.
    pkg.apply_patch 'resources/patches/curl/curl-7.55.1-aix-poll.patch'
  end

  if settings[:runtime_project].eql? 'pdk'
    pkg.build_requires "ruby-runtime"
  else
    pkg.build_requires "puppet-ca-bundle"
    pkg.build_requires "openssl-#{settings[:openssl_version]}" unless settings[:system_openssl]
  end

  if platform.is_cross_compiled_linux?
    if settings[:runtime_project].eql? 'pdk'
      pkg.build_requires 'ruby-runtime'
    else
      pkg.build_requires "runtime-#{settings[:runtime_project]}"
    end
    pkg.environment "PATH" => "/opt/pl-build-tools/bin:$(PATH):#{settings[:bindir]}"
    pkg.environment "PKG_CONFIG_PATH" => "/opt/puppetlabs/puppet/lib/pkgconfig"
    pkg.environment "PATH" => "/opt/pl-build-tools/bin:$(PATH)"
  elsif platform.is_windows?
    if settings[:runtime_project].eql? 'pdk'
      pkg.build_requires 'ruby-runtime'
    else
      pkg.build_requires "runtime-#{settings[:runtime_project]}"
    end
    pkg.environment "PATH" => "$(shell cygpath -u #{settings[:gcc_bindir]}):$(PATH)"
    pkg.environment "CYGWIN" => settings[:cygwin]
  else
    pkg.environment "PATH" => "/opt/pl-build-tools/bin:$(PATH):#{settings[:bindir]}"
  end

  configure_options = []
  unless settings[:system_openssl]
     configure_options << "--with-ssl=#{settings[:prefix]}"
  end

  if (platform.is_solaris? && platform.os_version == "11") || platform.is_aix?
    # Makefile generation with automatic dependency tracking fails on these platforms
    configure_options << "--disable-dependency-tracking"
  end

  pkg.configure do
    ["CPPFLAGS='#{settings[:cppflags]}' \
      LDFLAGS='#{settings[:ldflags]}' \
     ./configure --prefix=#{settings[:prefix]} \
        #{configure_options.join(" ")} \
        --enable-threaded-resolver \
        --disable-ldap \
        --disable-ldaps \
        --with-ca-bundle=#{settings[:prefix]}/ssl/cert.pem \
        --with-ca-path=#{settings[:prefix]}/ssl/certs \
        CFLAGS='#{settings[:cflags]}' \
        #{settings[:host]}"]
  end

  pkg.build do
    ["#{platform[:make]} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"]
  end

  install_steps = [
    "#{platform[:make]} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install",
  ]

  unless ['agent', 'pdk'].include?(settings[:runtime_project])
    # Most projects won't need curl binaries, so delete them after installation.
    # Note that the agent _should_ include curl binaries; Some projects and
    # scripts depend on them and they can be helpful in debugging.
    install_steps << "rm -f #{settings[:prefix]}/bin/{curl,curl-config}"
  end

  pkg.install do
    install_steps
  end
end
