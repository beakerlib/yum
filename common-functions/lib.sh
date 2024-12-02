#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/yum/Library/common-functions
#   Description: Provides various yum and rpm related functions
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = yumlib
#   library-version = 2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

yum/common-functions - Provides various yum and rpm related functions

=head1 DESCRIPTION

This library contain various functions shared across yum* and rpm* tests.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#true <<'=cut'
#=pod
#
#=head1 VARIABLES
#
#Below is the list of global variables. When writing a new library,
#please make sure that all global variables start with the library
#prefix to prevent collisions with other libraries.
#
#=over
#
#=item fileFILENAME
#
#Default file name to be used when no provided ('foo').
#
#=back
#
#=cut

#fileFILENAME="foo"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=head2 yumlibDisableYumPlugin

Makes backup of the respective *.conf file and disables the plugin.
If the plugin provides a *.repo file(s) (such as yum-plugin-local) also
repositories in this *.repo file(s) are disabled.
Use yumlibYumPluginRestore to restore the original *.conf and *.repo files.

    yumlibDisableYumPlugin [--ignoremissing] package [package2 ...]

=over

=item package

Name of the rpm package providing the plugin, e.g. yum-plugin-local.

=item --ignoremissing

Ignore not installed plugins

=back

Returns 0 when plugins are successfully disabled.
Returns 1 when some plugin isn't installed
Returns 2 when an installed plugin couldn't be disabled
Returns 3 when a *.repo file couldn't be disabled

=cut

yumlibDisableYumPlugin() {
    local RET
    local PKG
    local CONF
    local REPO
    local IGNOREMISSING
    IGNOREMISSING=0
    RET=0
    if [ "$1" == "--ignoremissing" ]; then
        IGNOREMISSING=1
        shift
    fi
    while [ -n "$1" ]; do
        PKG="$1"
        if rpm -q $PKG &> /dev/null; then
            CONF=`rpm -ql $PKG | egrep "(/etc/yum/pluginconf.d/|/etc/dnf/plugins/)" | xargs echo`
            rlFileBackup --namespace yumlibPluginBackup $CONF
	    rlLogInfo "Disabling plugin $PKG in $CONF"
            sed -i 's/enabled.*=.*/enabled=0/g' $CONF || RET=2
            # for plugin provides a repo disable also repo
            REPO=`rpm -ql $PKG | grep '/etc/yum.repos.d/.*\.repo' | xargs echo`
            if [ -n "$REPO" ]; then
                if [ -f $REPO ]; then
                    rlFileBackup --namespace yumlibPluginBackup $REPO
                    rlLogInfo "Disabling repos in $REPO"
                    sed -i 's/enabled.*=.*/enabled=0/g' $REPO || RET=3
                elif [ $IGNOREMISSING == "1" ]; then
                    rlLogInfo "Could not find repo $REPO from $PKG, ignoring"
                else
                    rlLogWarning "Could not find repo $REPO from $PKG"
                fi
            fi
	elif [ $IGNOREMISSING == "1" ]; then
            rlLogInfo "Ignoring missing plugin $PKG"
        else
            rlLogWarning "No such package $PKG"
            RET=1
        fi
        shift
    done
    rlFileBackup --namespace yumlibPluginBackup /var/tmp/yumlibLoaded # just a placeholder so we backup at least something
    return $RET
}


true <<'=cut'
=pod

=head2 yumlibYumPluginRestore

Restore *.conf files previously backed up by yumlibDisableYumPlugin calls.

    yumlibYumPluginRestore

=over

=back

Returns 0 when the restore is successfull, 1 otherwise.

=cut

yumlibYumPluginRestore() {
    rlFileRestore --namespace yumlibPluginBackup || return 1
}


###########################################################################################


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   yumlibDisableRepos
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 yumlibDisableRepos

Disable, backup and delete all repositories. (All repositories are stored in /etc/yum.repos.d-yumlib.backup/)

    yumlibDisableRepos

=over

=back

Returns 0 when the disabled successfully.
Returns 1 when moving files is unsuccessfull.
Returns 2 when dir with backup already exists.

=cut

yumlibDisableRepos(){
  if [ ! -d "/etc/yum.repos.d-yumlib.backup" ]; then
    rlLogInfo "Make dir /etc/yum.repos.d-yumlib.backup/ for backup"
    mkdir /etc/yum.repos.d-yumlib.backup
    rlLogInfo "Moving /etc/yum.repos.d/ to /etc/yum.repos.d-yumlib.backup/"
    mv /etc/yum.repos.d/*  /etc/yum.repos.d-yumlib.backup/ || {
      rlLogWarning "Moving files to yum.repos.d-yumlib.backup failed, stopping yumlibDisableRepos"
      return 1;
    }
    rlLogInfo "Removing files frome /etc/yum.repos.d/"
    rm -rf /etc/yum.repos.d/*
  else
    rlLogWarning "Repositories have been already disabled."
    rlLogDebug "Dir /etc/yum.repos.d-yumlib.backup is already created, check if there are necessary repos"
    return 2;
  fi
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   yumlibRestoreRepos
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 yumlibRestoreRepos

Restore repositories previously backed up by yumlibDisableRepos.

    yumlibRestoreRepos

=over

=back

Returns 0 when the restored successfully.
Returns 1 when backup dir doesn't exist.
Returns 2 when removing files from /etc/yum.repos.d/ failed
Returns 3 when moving backup to /etc/yum.repos.d/ failed.
Returns 4 when removing backup failed.

=cut

yumlibRestoreRepos(){

  if [ -f /var/tmp/yumlibRepoSetupLocal.repos ]; then
    rlLogWarning "You should call yumlibRepoCleanup() function! I am calling it for you!"
    yumlibRepoCleanup
  fi

  if [ -d "/etc/yum.repos.d-yumlib.backup" ]; then
    rlLogInfo "Removing files from /etc/yum.repos.d/"
    rm -rf /etc/yum.repos.d/* || { rlLogWarning "Removing files from /etc/yum.repos.d/ failed, stopping"
      return 2
    }
    rlLogInfo "Moving /etc/yum.repos.d-yumlib.backup/ back to /etc/yum.repos.d/"
    mv /etc/yum.repos.d-yumlib.backup/* /etc/yum.repos.d/ || { rlLogWarning "Moving failed, stopping"
      return 3
    }
    rlLogInfo "Removing /etc/yum.repos.d-yumlib.backup/"
    rm -rf /etc/yum.repos.d-yumlib.backup/ || { rlLogWarning "Removing backup failed, stopping"
      return 4
    }
  else
    rlLogWarning "There are no repositories to restore."
    rlLogDebug "Dir /etc/yum.repos.d-yumlib.backup does not exist, did you run yumlibDisableRepos before executing this?"
    return 1
  fi
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   yumlibRepoSetupLocal
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 yumlibRepoSetupLocal

Create repositories ,add them to yum repolist, and enable them.

    yumlibRepoSetupLocal repo_path1 [repo_path2 ...]

=over

=item --enabled

Set the repo to be enabled (default)

=item --disabled

Set the repo to be disabled

=item --option OPTION

append OPTION to the repo file
 
=item repo_path1

Path to desired local repository. Can be existing or nonexisting directory. Base directory names can't be duplicit.

=back

Returns 0 when the setup is successfull, 1 otherwise.

=cut

yumlibRepoSetupLocal(){
  local STATE=1
  local OPTIONS=$(mktemp)
  while [ "${1:0:1}" = "-" ]; do
    if [ "$1" == "--enabled" ]; then
      STATE=1
      shift 1
    elif [ "$1" == "--disabled" ]; then
      STATE=0
      shift 1
    elif [ "$1" == "--option" ]; then
      echo "$2" >> $OPTIONS
      shift 2
    else  # should not happen, just avoid infinite loop
      rlLogError "Unknown parameter $1"
      return 1
    fi
  done

  #Parse arguments, they should be only directory paths
  for arg in "$@"
  do
    rlLogDebug "Path to repository is $arg"
    local NAME=$(basename $arg)
    rlLogDebug "Name for repo is $NAME"

    #If base dirnames are equeal => error
    if [ -e "/etc/yum.repos.d/$NAME.repo" ]; then
      rlLogError "$NAME.repo already exists, you should use different name."
      return 1;
    fi

    #Create dir for repo if not exist
    if [ ! -e $arg ]; then
      mkdir -p $arg
      rlLogInfo "Created dir $arg"
    fi

    #if arg is not realpath to dir, get realpath
    if [[ ! $arg =~ ^[\/].* ]]; then
      arg=$(readlink -f $arg)
    fi

    #Create repo
    cat > /etc/yum.repos.d/$NAME.repo <<_EOF
[$NAME]
name=My Local Repo $NAME
baseurl=file://$arg/
enabled=$STATE
gpgcheck=0
_EOF
    cat $OPTIONS >> /etc/yum.repos.d/$NAME.repo
    createrepo $arg
    rlLogInfo "Created and added repository $NAME to /etc/yum.repos.d/"

    #Write created repo paths to tmp
    echo "$arg" >> /var/tmp/yumlibRepoSetupLocal.repos
  done
  rm -f $OPTIONS
} #end of yumlibRepoSetupLocal()



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   yumlibRepoCleanup
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 yumlibRepoCleanup

Clean up specified repositories or all repositories created by yumlibRepoSetupLocal.
It removes also yum metadata of specified repositories.
You should use this function every time you use yumlibRepoSetupLocal() in order to cleanup.
This should be called before yumlibRestoreRepos().

    yumlibRepoCleanup [repo_path1 ...]

=over

=item repo_path1

Path to local repository.

=back

Returns 0 when the cleanup is successfull, 1 otherwise.

=cut

#add parameter for cleanup of user defined repos.
yumlibRepoCleanup(){
  #If there are some files specified in arguments, proccess them
  if [[ $# > 0 ]]; then
    repos=$@
  else
    local repos=$(cat "/var/tmp/yumlibRepoSetupLocal.repos")
  fi

  for arg in $repos
  do
    local NAME=$(basename $arg)
    echo \"$arg\"
    rlRun "yum --disablerepo=\* --enablerepo=$NAME* clean all"
    if [ -d "$arg" ]; then
      rm -rf $arg
      rlLogInfo "deleting $arg"
    fi
    #Mby not needed, it wil be cleand with yumlibRestoreRepos
    if [ -e "/etc/yum.repos.d/$NAME.repo" ]; then
      rm -rf /etc/yum.repos.d/$NAME.repo
      rlLogInfo "deleting $NAME.repo"
    fi
  done

  #There wasn't any arguments, we can delete /var/tmp/yumlibRepoSetupLocal.repos
  if [[ $# < 1 ]]; then
    rm -f /var/tmp/yumlibRepoSetupLocal.repos
    rlLogInfo "Deleting /var/tmp/yumlibRepoSetupLocal.repos"
  fi

} #end of yumlibRepoCleanup



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   yumlibMakeDummyPKG
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#TODO: pridat parameter ci zmazat alebo nie tmp subor
true <<'=cut'
=pod

=head2 yumlibMakeDummyPKG

Create dummy package for testing.

    yumlibMakeDummyPKG  [--keepPKGTMP] [-s SPEC] [--requires FOO] [--provides FOO] [--obsoletes FOO] [--conflicts FOO] [PKGNAME] [[EPOCH:]VERSION] [RELEASE] [SIZE_IN_kB]

=over

=item --keepPKGTMP

Do not remove PKG.tmp from /tmp (which is removed by default).

=item --requires FOO

Add a pkg dependency.

=item --provides FOO

Adds pkg provides.

=item --obsoletes FOO

Adds pkg obsoletes.

=item --conflicts FOO

Adds pkg conflicts.

=back

Returns 0 when created successfully.
Returns 1 when build of the package failed.
Returns 2 when the path of the built package cannot be determined.
Returns 3 when moving the package into the current directory failed.

=cut

yumlibMakeDummyPKG(){

  if [ "$1" = "--keepPKGTMP" ]; then
    #if set, the /tmp/$PKGNAME.tmp won't be deleted
    local keepPKGTMP=1
    shift 1
  fi

# if I have a spec file, no need to create it
  if [ "$1" = "-s" ]; then
    local SPECFILE=$2
    #shift 2

  else
    local PKGNAME=dummy
    local VERSION=1.0
    local RELEASE=1
    local SIZE=0

    # process parameters and store them in a file
    local PARAMFILE=`mktemp`
    while [ "${1:0:1}" = "-" ]; do
      if [ "$1" = "--requires" ]; then
        echo "Requires: $2" >> $PARAMFILE
        shift 2
      fi
      if [ "$1" = "--provides" ]; then
        echo "Provides: $2" >> $PARAMFILE
        shift 2
      fi
      if [ "$1" = "--obsoletes" ]; then
        echo "Obsoletes: $2" >> $PARAMFILE
        shift 2
      fi
      if [ "$1" = "--conflicts" ]; then
        echo "Conflicts: $2" >> $PARAMFILE
        shift 2
      fi
      if [ "$1" = "--modularitylabel" ]; then
        echo "ModularityLabel: $2" >> $PARAMFILE
        shift 2
      fi
    done

    [ -n "$1" ] && PKGNAME=$1
    [ -n "$2" ] && EPOCH_VERSION=$2
    [ -n "$3" ] && RELEASE=$3
    [ -n "$4" ] && SIZE=$4
    local SPECFILE=$PKGNAME.spec
    
    if echo $EPOCH_VERSION | grep -q ':'; then
        EPOCH=${EPOCH_VERSION%%:*}
        VERSION=${EPOCH_VERSION#*:}
    else
        EPOCH=""
        if [ -n "$EPOCH_VERSION" ]; then VERSION=$EPOCH_VERSION; fi
    fi

    cat > $SPECFILE <<_EOF1
Summary: $PKGNAME Package
Name: $PKGNAME
_EOF1

    if [ "x$EPOCH" != "x" ]; then echo "Epoch: $EPOCH" >> $SPECFILE; fi

    cat >> $SPECFILE <<_EOF2
Version: $VERSION
Release: $RELEASE
Group: System Environment/Base
License: GPL
BuildArch: noarch
BuildRoot:  %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
_EOF2

    # include the PARAMFILE
    cat $PARAMFILE >> $SPECFILE

    # and continue
    cat >> $SPECFILE <<_EOF
%description

This is a $PKGNAME test package created by make_dummy_package.sh script

%build
_EOF

    # for SIZE>0 prepare a file of sufficient size
    rm -f $PKGNAME.tmp
    if [ $SIZE -gt 0 ]; then
      for file in /usr/bin/*; do
        gzip -c $file >> $PKGNAME.tmp
        [ `du $PKGNAME.tmp | awk '{ print \$1 }'` -gt $SIZE ] && break
      done
      tar -cf /tmp/$PKGNAME.tmp $PKGNAME.tmp
      rm -f $PKGNAME.tmp
    fi

    cat >> $SPECFILE <<_EOF
touch /tmp/$PKGNAME.tmp  # create it if not present
cp /tmp/$PKGNAME.tmp .  # just copy so it can be used in future rebuilds

%install
mkdir -p %{buildroot}/usr/local/
mv $PKGNAME.tmp %{buildroot}/usr/local/

%files
/usr/local/$PKGNAME.tmp
_EOF

  fi

local TmpFile=`mktemp`
if ! rpmbuild -ba $SPECFILE &> $TmpFile; then
  cat $TmpFile
  return 1
fi
local PkgPath=`grep 'Wrote:' $TmpFile | cut -d ' ' -f 2` || return 2
local PKGrpm=`grep 'Wrote:' $TmpFile | cut -d ' ' -f 2 | grep -v 'src.rpm'` || return 2
local PKGNames=""
local PKG

# print built packages (except srpm) to stdout - RHEL-6 basename doesn't know --multiple
for PKG in $PKGrpm; do 
    PKGNames="$PKGNames $( basename $PKG )"
done
echo $PKGNames

mv $PkgPath . || return 3  # move built file to a current directory
rm -f $TmpFile
if [ -e "$PARAMFILE" ]; then
  rm -f $PARAMFILE
fi

[[ $keepPKGTMP -eq 1 ]] || rm -rf /tmp/$PKGNAME.tmp
} #end of yumlibMakeDummyPKG

###########################################################################################


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Execution
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#true <<'=cut'
#=pod
#
#=head1 EXECUTION
#
#This library supports direct execution. When run as a task, phases
#provided in the PHASE environment variable will be executed.
#Supported phases are:
#
#=over
#
#=item Create
#
#Create a new empty file. Use FILENAME to provide the desired file
#name. By default 'foo' is created in the current directory.
#
#=item Test
#
#Run the self test suite.
#
#=back
#
#=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

yumlibLibraryLoaded() {
    if [ -f /var/tmp/yumlibRepoSetupLocal.repos ]; then
        rm -f /var/tmp/yumlibRepoSetupLocal.repos
        rlLogInfo "One of previously running tests didn't call yumlibRepoCleanup() function"
    fi
    rpm -q rpm yum yum-utils 
    touch /var/tmp/yumlibLoaded || return 1
    return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Karel Srot <ksrot@redhat.com>
Marek Marusic <mmarusic@redhat.com>

=back

=cut

