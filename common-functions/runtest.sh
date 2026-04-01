#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/yum/Library/common-functions
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

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PHASE=${PHASE:-Test}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport yum/common-functions"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

#    # Create file
#    if [[ "$PHASE" =~ "Create" ]]; then
#        rlPhaseStartTest "Create"
#            fileCreate
#        rlPhaseEnd
#    fi

    # Self test
    if [[ "$PHASE" =~ "Test" ]]; then
        rlPhaseStartTest "Test  yumlibDisableYumPlugin and yumlibYumPluginRestore"
        if yumlibIsDnf5; then
            PLUGIN=builddep
            PTH=$(stat /usr/lib*/dnf5/plugins | grep "File" | cut -d: -f2)
        rlRun "dnf --version &> ver.log"
            if  grep "$PLUGIN" ver.log &> /dev/null; then
                CONF=$(ls $PTH | grep $PLUGIN)
                rlFileBackup $PTH/$CONF
                rlRun "yumlibDisableYumPlugin $PLUGIN"
                rlRun "dnf --version &> ver2.log" 0
                rlAssertGrep "dnf5 version" ver2.log
                rlAssertNotGrep "name: $PLUGIN" ver2.log
                rlRun "yumlibYumPluginRestore"
                rlRun "dnf --version &> ver3.log" 0
                rlAssertGrep "dnf5 version" ver3.log
                rlAssertGrep "name: $PLUGIN" ver3.log
                rlFileRestore
            else
                rlLogWarning "$PLUGIN is not installed, I cannot run the test"
            fi
        else
            PLUGIN=yum-plugin-security
            if rpm -q $PLUGIN &> /dev/null; then
                CONF=/etc/yum/pluginconf.d/security.conf
                rlFileBackup $CONF
                rlRun "sed -i 's/enabled=.*/enabled=1/g' $CONF"
                rlRun "yumlibDisableYumPlugin $PLUGIN"
                rlAssertGrep 'enabled=0' $CONF
                rlRun "yumlibYumPluginRestore"
                rlAssertGrep 'enabled=1' $CONF
                rlFileRestore
            else
                rlLogWarning "$PLUGIN is not installed, I cannot run the test"
            fi
        fi
        rlPhaseEnd
    fi
#        rlPhaseStartTest "Test filename in parameter"
#            fileCreate "parameter-file"
#            rlAssertExists "parameter-file"
#        rlPhaseEnd
#        rlPhaseStartTest "Test filename in variable"
#            FILENAME="variable-file" fileCreate
#            rlAssertExists "variable-file"
#        rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
