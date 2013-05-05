class ruby($version = "2.0.0-p0") {
  include ruby::prereqs

  rubyinstall { "$version": }

}

define rubyinstall($version = $title) {
  $packages = $ruby::prereqs::packages

  # The rm at the start is legacy, as previous versions of this plugin
  # used to download the package as a zip file rather than cloning :(
  exec { 'rbenv-checkout':
    command => "rm -Rf /opt/ruby-build && git clone https://github.com/sstephenson/rbenv.git /opt/rbenv",
    creates => "/opt/rbenv/.git",
    require => Package[$packages],
    path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
    timeout => 0,
  }


  exec { 'ruby-build-checkout':
    command => "rm -Rf /opt/ruby-build && git clone https://github.com/sstephenson/ruby-build /opt/ruby-build",
    creates => "/opt/ruby-build/.git",
    require => Exec['rbenv-checkout'],
    path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
    timeout => 0,
  }

  exec { "ruby-build-update":
    command => "git checkout -f && git pull origin master",
    cwd     => "/opt/ruby-build",
    require => Exec["ruby-build-checkout"],
    path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
    timeout => 0
  }

  exec { "ruby-install-$version":
    command => "/opt/ruby-build/bin/ruby-build $version /opt/ruby-$version",
    creates => "/opt/ruby-$version",
    path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
    require => Exec["ruby-build-update"],
    timeout => 0
  }

  case $operatingsystem {
    'Ubuntu': {
      exec { "alternatives-ruby-$version":
        command => "update-alternatives --quiet --install /usr/bin/ruby ruby /opt/ruby-$version/bin/ruby 10 --slave /usr/bin/irb irb /opt/ruby-$version/bin/irb && update-alternatives --quiet --set ruby /opt/ruby-$version/bin/ruby",
        unless  => "test /usr/bin/ruby -ef /opt/ruby-$version/bin/ruby && test /usr/bin/irb -ef /opt/ruby-$version/bin/irb",
        path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
        require => Exec["ruby-install-$version"]
      }
      exec { "alternatives-gem-$version":
        command => "update-alternatives --quiet --install /usr/bin/gem gem /opt/ruby-$version/bin/gem 10 && update-alternatives --quiet --set gem /opt/ruby-$version/bin/gem",
        unless  => "test /usr/bin/gem -ef /opt/ruby-$version/bin/gem",
        path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
        require => Exec["alternatives-ruby-$version"]
      }

      exec { "gem-install-bundler-$version":
        command => "gem install bundler",
        unless  => "gem list | grep bundler",
        timeout => "-1",
        path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
        require => Exec["alternatives-gem-$version"]
      }
      exec { "alternatives-bundle-$version":
        command => "update-alternatives --quiet --install /usr/bin/bundle bundle /opt/ruby-$version/bin/bundle 10 && update-alternatives --quiet --set bundle /opt/ruby-$version/bin/bundle",
        unless  => "test /usr/bin/bundle -ef /opt/ruby-$version/bin/bundle",
        path    => ["/usr/sbin", "/usr/bin", "/sbin", "/bin"],
        require => Exec["gem-install-bundler-$version"]
      }
    }
  }
  }
