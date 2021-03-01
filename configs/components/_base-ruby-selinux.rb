# This file is a basis for multiple versions/targets of ruby-selinux.
# It should not be included as a component; Instead other components should
# load it with instance_eval. See ruby-x.y-selinux.rb configs.
#

# These can be overridden by the including component.
ruby_version ||= settings[:ruby_version]
host_ruby ||= settings[:host_ruby]
ruby_bindir ||= settings[:ruby_bindir]

if platform.name =~ /^el-5-.*$/
  # This is a _REALLY_ old version of libselinux found only in Fedora/RH archives and not upstream
  pkg.version "1.33.4"
  pkg.md5sum "08762379de2242926854080dad649b67"
  pkg.apply_patch "resources/patches/ruby-selinux/libselinux-rhat.patch"
  pkg.url "http://pkgs.fedoraproject.org/repo/pkgs/libselinux/libselinux-1.33.4.tgz/08762379de2242926854080dad649b67/libselinux-1.33.4.tgz"
  pkg.mirror "#{settings[:buildsources_url]}/libselinux-#{pkg.get_version}.tgz"

  # This version of libselinux does not supply a file for pkg-config; Augeas 1.10.1 expects one, though:
  pkg.add_source "file://resources/files/ruby-selinux/libselinux-1.33.4.pc"
  pkg.install do
    ["cp ../libselinux-1.33.4.pc #{settings[:libdir]}/pkgconfig/libselinux.pc"]
  end
elsif platform.name =~ /el-(5|6|7)|debian-(8|9)|ubuntu-(16|18)/
  pkg.version "2.0.94"
  pkg.md5sum "544f75aab11c2af352facc51af12029f"
  pkg.url "https://raw.githubusercontent.com/wiki/SELinuxProject/selinux/files/releases/20100525/devel/libselinux-#{pkg.get_version}.tar.gz"
  pkg.mirror "#{settings[:buildsources_url]}/libselinux-#{pkg.get_version}.tar.gz"
else
  pkg.version "2.9"
  pkg.md5sum "bb449431b6ed55a0a0496dbc366d6e31"
  pkg.apply_patch "resources/patches/ruby-selinux/selinux-29-function.patch"
  pkg.url "https://github.com/SELinuxProject/selinux/releases/download/20190315/libselinux-#{pkg.get_version}.tar.gz"
  pkg.mirror "#{settings[:buildsources_url]}/libselinux-#{pkg.get_version}.tar.gz"
end

if settings[:runtime_project].eql? 'pdk'
  pkg.build_requires "ruby-runtime"
else
  pkg.build_requires "ruby-#{ruby_version}"
end

cc = "/opt/pl-build-tools/bin/gcc"
system_include = "-I/usr/include"
ruby = "#{ruby_bindir}/ruby -rrbconfig"

if platform.is_cross_compiled_linux?
  cc = "/opt/pl-build-tools/bin/#{settings[:platform_triple]}-gcc"
  system_include = "-I/opt/pl-build-tools/#{settings[:platform_triple]}/sysroot/usr/include"
  pkg.environment "RUBY", host_ruby
  ruby = "#{host_ruby} -r#{settings[:datadir]}/doc/rbconfig-#{ruby_version}-orig.rb"
end

cflags = ""

# The platforms below use pl-build-tools
unless platform.name =~ /el-(5|6|7)|debian-(8|9)|ubuntu-(16|18)/
  cc = '/usr/bin/gcc'
  cflags += "#{settings[:cppflags]} #{settings[:cflags]}"
end

pkg.build do
  [
    "export RUBYHDRDIR=$(shell #{ruby} -e 'puts RbConfig::CONFIG[\"rubyhdrdir\"]')",
    "export VENDORARCHDIR=$(shell #{ruby} -e 'puts RbConfig::CONFIG[\"vendorarchdir\"]')",
    "export ARCHDIR=$${RUBYHDRDIR}/$(shell #{ruby} -e 'puts RbConfig::CONFIG[\"arch\"]')",
    "export INCLUDESTR=\"-I#{settings[:includedir]} -I$${RUBYHDRDIR} -I$${ARCHDIR}\"",
    "cp -pr src/{selinuxswig_ruby.i,selinuxswig.i} .",
    "swig -Wall -ruby #{system_include} -o selinuxswig_ruby_wrap.c -outdir ./ selinuxswig_ruby.i",
    "#{cc} $${INCLUDESTR} #{system_include} #{cflags} -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 -fPIC -DSHARED -c -o selinuxswig_ruby_wrap.lo selinuxswig_ruby_wrap.c",
    "#{cc} $${INCLUDESTR} #{system_include} -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 -shared -o _rubyselinux.so selinuxswig_ruby_wrap.lo -lselinux -Wl,-z,relro,-z,now,-soname,_rubyselinux.so",
  ]
end

pkg.install do
  [
    "export VENDORARCHDIR=$(shell #{ruby} -e 'puts RbConfig::CONFIG[\"vendorarchdir\"]')",
    "install -d $${VENDORARCHDIR}",
    "install -p -m755 _rubyselinux.so $${VENDORARCHDIR}/selinux.so",
    "#{platform[:make]} -e clean",
  ]
end
