require 'spec_helper'

describe 'dlrn::worker' do
  let :facts do
  {  :os                        => {
          'family' => 'RedHat',
          'release' => {
              'major' => '7',
              'minor' => '1',
              'full'  => '7.6.1810',
           },
          'selinux' => {
              'enabled' => true,
          }
      },
      :osfamily                  => 'RedHat',
      :operatingsystem           => 'Fedora',
      :operatingsystemrelease    => '24',
      :operatingsystemmajrelease => '24',
      :concat_basedir            => '/tmp',
      :puppetversion             => '3.7.0',
      :selinux                   => true,
      :sudoversion               => '1.8.15',
      :processorcount            => 2 }
  end

  let :params do {
    :distro           => 'centos7',
    :target           => 'centos',
    :distgit_branch   => 'rpm-master',
    :distro_branch    => 'master',
    :disable_email    => true,
    :enable_cron      => false,
    :server_type      => 'primary',
    }
  end

  let(:pre_condition) { [
      'include ::apache',
      'include ::dlrn::common',
  ] }

  context 'with default parameters' do
    ['fedora-master', 'centos-master', 'centos-rocky'].each do |user|
      describe "when user is #{user}" do
        let :title do
          user
        end

        it 'creates user' do
          is_expected.to contain_user("#{user}").with(
            :groups     => ['users','mock'],
            :uid        => nil,
            :managehome => 'true',
          )
        end

        it 'sets owner on home directory' do
          is_expected.to contain_file("/home/#{user}").with(
            :ensure => 'directory',
            :mode   => '0755',
            :owner  => "#{user}",
          ).with_before(/Exec\[ensure home contents belong to #{user}\]/)
        end

        it 'creates the data directory' do
          is_expected.to contain_file("/home/#{user}/data").with(
            :ensure  => 'directory',
            :mode    => '0755',
            :owner   => "#{user}",
          ).with_before(/File\[\/home\/#{user}\/data\/repos\]/)
        end

        it 'creates the data/repos directory' do
          is_expected.to contain_file("/home/#{user}/data/repos").with(
            :ensure  => 'directory',
            :mode => '0755',
            :owner   => "#{user}",
          ).with_before(/File\[\/home\/#{user}\/data\/repos\/dlrn-deps.repo\]/)
        end

        it 'creates the dlrn-deps.repo file' do
          is_expected.to contain_file("/home/#{user}/data/repos/dlrn-deps.repo").with(
            :source => "puppet:///modules/dlrn/#{user}-dlrn-deps.repo",
            :mode   => '0644',
            :owner  => "#{user}",
            :group  => "#{user}",
          )
        end

        it 'creates the delorean-deps.repo compat symlink' do
          is_expected.to contain_file("/home/#{user}/data/repos/delorean-deps.repo").with(
            :ensure => 'link',
            :target => "/home/#{user}/data/repos/dlrn-deps.repo",
          )
        end

        it 'creates the sudo entry' do
          is_expected.to contain_sudo__conf("#{user}").with(
            :priority => '10',
            :content  => "#{user} ALL=(ALL) NOPASSWD: /bin/rm",
          )
        end

        it 'creates a log removal cron job' do
          is_expected.to contain_cron("#{user}-logrotate").with(
            :command => "/usr/bin/find /home/#{user}/dlrn-logs/*.log -mtime +2 -exec rm {} \\;",
            :user    => "#{user}",
            :hour    => '4',
            :minute  => '0',
          )
        end

        it 'configures the venv' do
          is_expected.to contain_file("/home/#{user}/setup_dlrn.sh").with(
            :ensure  => 'present',
            :mode    => '0755',
          )
          is_expected.to contain_exec("pip-install-#{user}").with(
            :command => "/home/#{user}/setup_dlrn.sh",
            :cwd     => "/home/#{user}/dlrn",
            :creates => "/home/#{user}/.venv/bin/dlrn",
          )
        end

        it { is_expected.to contain_cron("#{user}").with(
            :ensure => 'absent',
          )
        }
        it 'does not set smtpserver in projects.ini' do
          is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
          .with_content(/smtpserver=$/)
        end

        it 'sets the default release in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/tags=rocky$/)
        end

        it 'does not set a gerrit user in projects.ini' do
            is_expected.not_to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/gerrit=$/)
        end

        it 'does not set rsyncdest in projects.ini' do
            is_expected.not_to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/rsyncdest=/)
        end

        it 'does set rsyncport to 22 in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/rsyncport=22$/)
        end

        it 'sets the rdoinfo driver in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/pkginfo_driver=dlrn.drivers.rdoinfo.RdoInfoDriver$/)
        end

        it 'sets the mock build driver in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/build_driver=dlrn.drivers.mockdriver.MockBuildDriver$/)
        end

        it 'configures 1 worker in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/workers=1$/)
        end

        it 'configures the default db connection string' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/database_connection=sqlite:\/\/\/commits.sqlite$/)
        end

        it 'sets fallback_to_master to true' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/fallback_to_master=true$/)
        end

        it 'sets include_srpm_in_repo to true' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/include_srpm_in_repo=true$/)
        end

        it 'configures the default release numbering scheme' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/release_numbering=0.date.hash$/)
        end

        it 'creates the API directory' do
            is_expected.to contain_file("/home/#{title}/api").with(
              :ensure  => 'directory',
              :mode    => '0755',
              :owner   => "root",
              :group   => "root",
              :require => "File[/home/#{title}]",
            )
        end

        it 'creates the WSGI config file' do
          is_expected.to contain_file("/home/#{title}/api/dlrn-api-#{title}.cfg")
            .with_content(/DB_PATH = \'sqlite:\/\/\/\/home\/#{title}\/dlrn\/commits.sqlite\'$/)
        end

        it 'sets a config file path in the WSGI config file' do
          is_expected.to contain_file("/home/#{title}/api/dlrn-api-#{title}.cfg")
            .with_content(/CONFIG_FILE = \'\/usr\/local\/share\/dlrn\/#{title}\/projects.ini'$/)
        end

        it 'does not create a cronjob for deps sync' do
          is_expected.not_to contain_cron("#{user}-deps").with(
            :command => '/usr/local/bin/update-deps.sh',
            :user    => "#{user}",
            :hour    => '*',
            :minute  => '10,40',
          )
        end

        it 'does not create a cronjob for build deps sync' do
          is_expected.not_to contain_cron("#{user}-deps").with(
            :command => 'TAG_PHASE="build" DEPS_DIR="${HOME}/data/repos/build-deps/" /usr/local/bin/update-deps.sh > $HOME/dlrn-logs/update-build-deps-$(date +\%Y\%m\%d\%H\%M).log 2>&1',
            :user    => "#{user}",
            :hour    => '*',
            :minute  => '25,55',
          )
        end
      end

      context 'with a custom db connection string' do
        before :each do
          params.merge!(:db_connection => 'mysql+pymysql://user:password@serverIP/dlrn')
        end

        let :title do
          user
        end

        it 'configures the custom db connection string' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/database_connection=mysql\+pymysql:\/\/user:password@serverIP\/dlrn$/)
        end

        it 'creates the WSGI config file' do
          is_expected.to contain_file("/home/#{title}/api/dlrn-api-#{title}.cfg")
          .with_content(/DB_PATH = \'mysql\+pymysql:\/\/user:password@serverIP\/dlrn\'$/)
        end
      end

      context 'with the newer release numbering scheme' do
        before :each do
          params.merge!(:release_numbering => '0.1.date.hash')
        end

        let :title do
          user
        end

        it 'configures the custom release numbering scheme' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/release_numbering=0.1.date.hash$/)
        end
      end

      context 'with the minor.date.hash release numbering scheme' do
        before :each do
          params.merge!(:release_numbering => 'minor.date.hash')
          params.merge!(:release_minor => '1')
        end

        let :title do
          user
        end

        it 'configures the custom release numbering scheme' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/release_numbering=minor.date.hash$/)
        end

        it 'sets the right release_minor value' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/release_minor=1$/)
        end
      end

      context 'with an invalid release numbering scheme' do
        before :each do
          params.merge!(:release_numbering => 'foo')
        end

        let :title do
          user
        end

        it 'will fail' do
            is_expected.to raise_error(Puppet::Error, /Invalid release numbering scheme specified/)
        end
      end

      context 'with a specific number of workers' do
        before :each do
          params.merge!(:worker_processes => '4')
        end

        let :title do
          user
        end

        it 'configures 4 workers in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/workers=4$/)
        end
      end

      context 'when not allowing fallback to master' do
        before :each do
          params.merge!(:fallback_to_master => 'false')
        end

        let :title do
          user
        end

        it 'configures fallback_to_master=false' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/fallback_to_master=false$/)
        end
      end

      context 'when not including srpms in repos' do
        before :each do
          params.merge!(:include_srpm_in_repo => 'false')
        end

        let :title do
          user
        end

        it 'configures include_srpm_in_repo=false' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/include_srpm_in_repo=false$/)
        end
      end

      context 'with specific uid' do
        before :each do
          params.merge!(:uid => '1001')
        end

        let :title do
          user
        end

        it 'creates user with defined uid' do
          is_expected.to contain_user("#{user}").with(
            :uid => '1001'
          )
        end
      end

      context 'with enabled cron job and default cron params' do
        before :each do
          params.merge!(:enable_cron => true)
        end

        let :title do
          user
        end

        it 'creates cron job' do
          is_expected.to contain_cron("#{user}").with(
            :command => 'DLRN_ENV= /usr/local/bin/run-dlrn.sh',
            :user    => "#{user}",
            :hour    => '*',
            :minute  => '*/5',
          )
        end
      end

      context 'with enabled cron job and a command-line param' do
        before :each do
          params.merge!(:enable_cron => true)
          params.merge!(:cron_env => '--head-only')
        end

        let :title do
          user
        end

        it 'creates cron job' do
          is_expected.to contain_cron("#{user}").with(
            :command => 'DLRN_ENV=--head-only /usr/local/bin/run-dlrn.sh',
            :user    => "#{user}",
            :hour    => '*',
            :minute  => '*/5',
          )
        end
      end

      context 'with enabled cron job and a specific schedule' do
        before :each do
          params.merge!(:enable_cron => true)
          params.merge!(:cron_hour => '*/12')
          params.merge!(:cron_minute => '30')
        end

        let :title do
          user
        end

        it 'creates cron job' do
          is_expected.to contain_cron("#{user}").with(
            :command => 'DLRN_ENV= /usr/local/bin/run-dlrn.sh',
            :user    => "#{user}",
            :hour    => '*/12',
            :minute  => '30',
          )
        end
      end

      context 'with enabled purge job and default params' do
        before :each do
          params.merge!(:enable_purge => true)
        end

        let :title do
          user
        end

        it 'creates cron job' do
          is_expected.to contain_cron("#{user}-purge").with(
            :command => '/usr/local/bin/run-purge.sh',
            :user    => "#{user}",
            :hour    => '1',
            :minute  => '7',
          )
        end
      end

      context 'with enabled purge job and a specific schedule' do
        before :each do
          params.merge!(:enable_purge => true)
          params.merge!(:purge_hour => '5')
          params.merge!(:purge_minute => '35')
        end

        let :title do
          user
        end

        it 'creates cron job' do
          is_expected.to contain_cron("#{user}-purge").with(
            :command => '/usr/local/bin/run-purge.sh',
            :user    => "#{user}",
            :hour    => '5',
            :minute  => '35',
          )
        end
      end


      context 'with enabled emails' do
        before :each do
          params.merge!(:disable_email => false)
        end

        let :title do
          user
        end

        it 'sets smtpserver in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/smtpserver=localhost$/)
        end
      end

      context 'with symlinks' do
        before :each do
          params.merge!(:symlinks => ['/var/www/html/f24','/var/www/html/fedora24'])
        end

        let :title do
          user
        end

        it 'creates symlinks' do
          is_expected.to contain_file('/var/www/html/f24').with(
            :ensure  => 'link',
            :target  => "/home/#{user}/data/repos",
            :require => 'Package[httpd]',
          )
        end
      end

      context 'when specifying release' do
        before :each do
          params.merge!(:release => 'stein')
        end

        let :title do
          user
        end

        it 'sets tags in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/tags=stein$/)
        end
      end

      context 'when setting a gerrit user' do
        before :each do
          params.merge!(:gerrit_user => 'foo')
          params.merge!(:gerrit_email => 'foo@rdoproject.org')
        end

        let :title do
          user
        end

        it 'sets a gerrit user in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/gerrit=yes$/)
        end

        it 'configures the gerrit user' do
          is_expected.to contain_exec("Set gerrit user for #{user}").with(
            :command => "git config --global --add gitreview.username foo",
            :require => "File[/home/#{user}]",
          )

          is_expected.to contain_exec("Set git user for #{user}").with(
            :command => "git config --global user.name foo",
            :require => "File[/home/#{user}]",
          )

          is_expected.to contain_exec("Set git email for #{user}").with(
            :command => "git config --global user.email foo@rdoproject.org",
            :require => "File[/home/#{user}]",
          )
        end

        it 'sets the default Gerrit topic' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/gerrit_topic=rdo-FTBFS$/)
        end

        it 'sets up the required SSH keys' do
          is_expected.to contain_sshkey('review.rdoproject.org').with(
            :ensure => 'present',
            :name   => '[review.rdoproject.org]:29418',
          )
        end
      end

      context 'when setting a specific gerrit topic' do
        before :each do
          params.merge!(:gerrit_user => 'foo')
          params.merge!(:gerrit_email => 'foo@rdoproject.org')
          params.merge!(:gerrit_topic => 'rdo-FTBFS-anotherbranch')
        end

        let :title do
          user
        end

        it 'sets the right Gerrit topic' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/gerrit_topic=rdo-FTBFS-anotherbranch$/)
        end
      end

      context 'when setting the gitrepo driver' do
        before :each do
          params.merge!(:pkginfo_driver => 'dlrn.drivers.gitrepo.GitRepoDriver')
          params.merge!(:gitrepo_skip   => ['pkg1', 'pkg2'])
        end

        let :title do
          user
        end

        it 'sets the proper driver in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/pkginfo_driver=dlrn.drivers.gitrepo.GitRepoDriver$/)
        end

        it 'sets the proper skip in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/skip=pkg1,pkg2$/)
        end

        it 'sets use_version_from_spec to true in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/use_version_from_spec=true$/)
        end
      end

      context 'when setting the Koji build driver' do
        before :each do
          params.merge!(:build_driver           => 'dlrn.drivers.kojidriver.KojiBuildDriver')
          params.merge!(:koji_exe               => 'brew')
          params.merge!(:koji_krb_principal     => 'test@example.com')
          params.merge!(:koji_krb_keytab        => '/home/test/test.keytab')
          params.merge!(:koji_build_target      => 'testtarget')
          params.merge!(:koji_arch              => 'aarch64')
          params.merge!(:koji_fetch_mock_config => true)
        end

        let :title do
          user
        end

        it 'sets the proper driver in projects.ini' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/build_driver=dlrn.drivers.kojidriver.KojiBuildDriver$/)
        end

        it 'sets the default value for scratch_builds and use_rhpkg' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/scratch_build=true$/)
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/use_rhpkg=false$/)
        end

        it 'sets the proper value for koji_exe' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/koji_exe=brew$/)
        end

        it 'sets the proper value for koji_arch' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/arch=aarch64$/)
        end

        it 'sets the proper value for koji_fetch_mock_config' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/fetch_mock_config=true$/)
        end

        it 'sets the default value for koji_krb_principal' do
            is_expected.to contain_file("/usr/local/share/dlrn/#{user}/projects.ini")
            .with_content(/krb_principal=test@example.com$/)
        end
      end

      context 'when setting a gerrit user but not an email' do
        before :each do
          params.merge!(:gerrit_user => 'foo')
        end

        let :title do
          user
        end

        it 'should fail' do
          is_expected.to raise_error(Puppet::Error,/gerrit_email not set, but gerrit_user is set/)
        end
      end
    end
  end

  context 'when running on master' do
    let :title do
      'centos-master'
    end

    it 'sets default baseurl in projects.ini' do
        is_expected.to contain_file("/usr/local/share/dlrn/centos-master/projects.ini")
        .with_content(/baseurl=http:\/\/localhost$/)
    end

    it 'creates mock config file with disabled mock_tmpfs' do
      is_expected.to contain_file("/home/centos-master/dlrn/scripts/centos.cfg")
      .with_content(/config_opts\[\'plugin_conf\'\]\[\'tmpfs\_enable\'\] = False/)
    end

    context 'when enabling mock_tmpfs' do
      before :each do
        params.merge!(:mock_tmpfs_enable => true)
      end

      it 'creates mock config file with enabled mock_tmpfs' do
        is_expected.to contain_file("/home/centos-master/dlrn/scripts/centos.cfg")
        .with_content(/config_opts\[\'plugin_conf\'\]\[\'tmpfs\_enable\'\] = True/)
      end
    end
  end

  context 'with special case for centos-train' do
    before :each do
      params.merge!(:release             => 'train')
      params.merge!(:target              => 'centos-train')
      params.merge!(:distro_branch       => 'stable/train')
      params.merge!(:baseurl             => 'https://trunk.rdoproject.org/centos7-foo')
      params.merge!(:enable_public_rsync => true)
    end

    let :title do
      'centos-train'
    end

    it 'creates specific mock config file for centos-train' do
      is_expected.to contain_file('/home/centos-train/dlrn/scripts/centos-train.cfg')
      .with_content(/config_opts\[\'root\'\] = \'dlrn-centos-train-x86_64\'/)
    end

    it 'creates directory under /var/www/html' do
      is_expected.to contain_file('/var/www/html/train').with(
        :ensure  => 'directory',
        :mode    => '0755',
        :path    => '/var/www/html/train',
        :require => 'Package[httpd]',
      )
    end

    it 'sets a custom baseurl in projects.ini' do
        is_expected.to contain_file("/usr/local/share/dlrn/centos-train/projects.ini")
        .with_content(/baseurl=https:\/\/trunk.rdoproject.org\/centos7-foo$/)
    end

    it 'configures rsync module' do
        is_expected.to contain_rsync__server__module('centos-train').with(
            :path        => '/home/centos-train/data/repos',
            :hosts_allow => nil,
        )
    end
  end

  context 'when enabling public rsync for centos-master-uc, and setting specific allowed hosts' do
    before :each do
      params.merge!(:release                  => 'train-uc')
      params.merge!(:target                   => 'centos-master-uc')
      params.merge!(:distro_branch            => 'master')
      params.merge!(:baseurl                  => 'https://trunk.rdoproject.org/centos7')
      params.merge!(:enable_public_rsync      => true)
      params.merge!(:public_rsync_hosts_allow => ['foo.example.com'])
    end

    let :title do
      'centos-master-uc'
    end

    it 'configures rsync module with the proper name and allowed hosts' do
        is_expected.to contain_rsync__server__module('centos7').with(
            :path        => '/home/centos-master-uc/data/repos',
            :hosts_allow => ['foo.example.com'],
        )
    end
  end

  context 'with rsyncdest parameter parameter' do
    before :each do
      params.merge!(:rsyncdest       => 'centos-stein@backupserver.example.com:/home/centos-stein/data/repos')
      params.merge!(:rsyncport       => 1022)
    end

    let :title do
      'centos-stein'
    end

    it 'sets rsyncdest in projects.ini' do
        is_expected.to contain_file("/usr/local/share/dlrn/centos-stein/projects.ini")
        .with_content(/rsyncdest=centos-stein@backupserver.example.com:\/home\/centos-stein\/data\/repos$/)
    end

    it 'does set rsyncport to 1022 in projects.ini' do
        is_expected.to contain_file("/usr/local/share/dlrn/centos-stein/projects.ini")
        .with_content(/rsyncport=1022$/)
    end
  end

  context 'with :enable_deps_sync parameter set to true' do
    before :each do
      params.merge!(:enable_deps_sync => true)
      params.merge!(:enable_purge => false)
    end

    let :title do
      'centos-queens'
    end

    it 'does create a cronjob for deps sync' do
      is_expected.to contain_cron('centos-queens-deps').with(
        :command => '/usr/local/bin/update-deps.sh > $HOME/dlrn-logs/update-deps-$(date +\%Y\%m\%d\%H\%M).log 2>&1',
        :user    => 'centos-queens',
        :hour    => '*',
        :minute  => [10, 40],
      )
    end

    it 'does creates a deps directory' do
      is_expected.to contain_file("/home/#{title}/data/repos/deps").with(
        :ensure  => 'directory',
        :mode    => '0755',
        :owner   => 'centos-queens',
        :group   => 'centos-queens',
      )
    end

    it 'does creates a deps/latest directory' do
      is_expected.to contain_file("/home/#{title}/data/repos/deps/latest").with(
        :ensure  => 'directory',
        :mode    => '0755',
        :owner   => 'centos-queens',
        :group   => 'centos-queens',
      )
    end

    it 'does creates a deps/latest/noarch directory' do
      is_expected.to contain_file("/home/#{title}/data/repos/deps/latest/noarch").with(
        :ensure  => 'directory',
        :mode    => '0755',
        :owner   => 'centos-queens',
        :group   => 'centos-queens',
      )
    end

    it 'does not create a cron job to purge dependencies' do
        is_expected.not_to contain_cron("#{title}-deps-purge")
    end
  end

  context 'with :enable_brs_sync parameter set to true' do
    before :each do
      params.merge!(:enable_brs_sync => true)
      params.merge!(:enable_purge => true)
    end

    let :title do
      'centos-queens'
    end

    it 'does create a cronjob for build deps sync' do
      is_expected.to contain_cron('centos-queens-build-deps').with(
        :command => 'TAG_PHASE="build" DEPS_DIR="${HOME}/data/repos/build-deps/" /usr/local/bin/update-deps.sh > $HOME/dlrn-logs/update-build-deps-$(date +\%Y\%m\%d\%H\%M).log 2>&1',
        :user    => 'centos-queens',
        :hour    => '*',
        :minute  => [25, 55],
      )
    end

    it 'does creates a build-deps directory' do
      is_expected.to contain_file("/home/#{title}/data/repos/build-deps").with(
        :ensure  => 'directory',
        :mode    => '0755',
        :owner   => 'centos-queens',
        :group   => 'centos-queens',
      )
    end

    it 'does creates a build-deps/latest directory' do
      is_expected.to contain_file("/home/#{title}/data/repos/build-deps/latest").with(
        :ensure  => 'directory',
        :mode    => '0755',
        :owner   => 'centos-queens',
        :group   => 'centos-queens',
      )
    end

    it 'does creates a build-deps/latest/noarch directory' do
      is_expected.to contain_file("/home/#{title}/data/repos/build-deps/latest/noarch").with(
        :ensure  => 'directory',
        :mode    => '0755',
        :owner   => 'centos-queens',
        :group   => 'centos-queens',
      )
    end

    it 'creates the rdo-trunk-runtime-deps.repo file' do
      is_expected.to contain_file("/home/centos-queens/data/repos/rdo-trunk-runtime-deps.repo").with(
        :ensure => 'present',
        :source => 'puppet:///modules/dlrn/centos-queens-rdo-trunk-runtime-deps.repo',
        :mode   => '0644',
        :owner  => 'centos-queens',
        :group  => 'centos-queens',)
    end

    it 'does create a cronjob for deps purge' do
      is_expected.to contain_cron('centos-queens-deps-purge').with(
        :command => '/usr/local/bin/purge-deps.sh',
        :user    => 'centos-queens',
        :hour    => '3',
        :minute  => '0',
      )
    end
  end

  context 'with parameter server_type = passive' do
    before :each do
      params.merge!(:server_type    => 'passive')
    end

    context 'with centos-stein name' do
      before :each do
        params.merge!(:distro_branch   => 'stable/stein')
        params.merge!(:release         => 'stein')
        params.merge!(:enable_cron     => true)
        params.merge!(:gerrit_user     => 'foo')
        params.merge!(:gerrit_email    => 'foo@rdoproject.org')
        params.merge!(:disable_email   => false)
      end

      let :title do
        'centos-stein'
      end

      it { is_expected.not_to contain_cron("#{title}") }

      it 'does not set a gerrit user in projects.ini' do
        is_expected.not_to contain_file("/usr/local/share/dlrn/#{title}/projects.ini")
        .with_content(/gerrit=yes$/)
      end

      it 'sets empty smtpserver in projects.ini' do
        is_expected.to contain_file("/usr/local/share/dlrn/#{title}/projects.ini")
        .with_content(/smtpserver=$/)
      end
    end

    context 'with fedora-stein name' do
      before :each do
        params.merge!(:distro_branch   => 'stable/stein')
        params.merge!(:release         => 'stein')
      end

      let :title do
        'fedora-stein'
      end

      it { is_expected.not_to contain_cron("#{title}") }
    end

    context 'with centos-master name' do
      before :each do
        params.merge!(:distro_branch   => 'master')
        params.merge!(:release         => 'rocky')
        params.merge!(:enable_cron     => true)
        params.merge!(:rsyncdest       => 'centos-master@backupserver.example.com:/home/centos-master/data/repos')
        params.merge!(:rsyncport       => 1022)
      end

      let :title do
        'centos-master'
      end

      it { is_expected.not_to contain_cron("#{title}") }

      it 'does not set rsyncdest in projects.ini' do
        is_expected.not_to contain_file("/usr/local/share/dlrn/#{title}/projects.ini")
        .with_content(/rsyncdest=/)
      end

      it 'does not set rsyncport in projects.ini' do
        is_expected.not_to contain_file("/usr/local/share/dlrn/#{title}/projects.ini")
        .with_content(/rsyncport=/)
      end
    end

    context 'with centos-queens name' do
      before :each do
        params.merge!(:enable_deps_sync => true)
      end

      let :title do
        'centos-queens'
      end

      it 'does not create a cronjob for deps sync' do
        is_expected.not_to contain_cron('centos-queens-deps').with(
          :command => '/usr/local/bin/update-deps.sh > $HOME/dlrn-logs/update-deps-$(date +\%Y\%m\%d\%H\%M).log 2>&1',
          :user    => 'centos-queens',
          :hour    => '*',
          :minute  => '10,40',
        )
      end

    end
  end
end

