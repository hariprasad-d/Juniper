#!/usr/bin/env python

from __future__ import absolute_import
from __future__ import print_function
from __future__ import unicode_literals

import pexpect, fileinput
import sys, argparse, getpass, re


def print_console_op(child):
    #sys.stdout.write (child.before)
    #sys.stdout.write (child.after)
    print (child.before)
    print (child.after)

def update_ssh_know_host(child, host):
    print(child.before)
    lines = child.before.splitlines();
    for line in lines:
        if 'Offending key' in line:
            words = line.split();
            for word in words:
                if 'known_hosts' in word:
                    filename = (word.split(':'))[0]
                    print(filename)
                    #delete the host key.
                    for ssh_host_list in fileinput.input(filename, inplace=True):
                        if host in ssh_host_list:
                            continue
                        print(ssh_host_list, end='')
                    break


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("host", help="host ip/name: default [10.204.96.200]", default='10.204.96.200')
    parser.add_argument("-u","--user", help="user default [root]", default='root')
    parser.add_argument("-t","--telnet", help="telnet to the serial console for the given host",
                                default=False, action='store_true')
    args = parser.parse_args()       
    #print("spawing scp session to [%s] for user [%s]" % (args.host, args.user))

    if args.user == 'regress':
        passwrd = 'MaRtInI'
    elif args.user == 'root':
       passwrd = 'Embe1mpls'
    elif args.user == 'hprasad':
       passwrd = 'op12OP!@'
    else:
       passwrd = getpass.getpass('Password:')

    if args.telnet is True:
        spawn_telnet_session(argv, args, passwrd)
    else:
        matchobj = re.search( r'-con$', args.host, re.M|re.I)
        if matchobj:
            spawn_telnet_session(argv, args, passwrd)
        else:
            spawn_ssh_session(argv, args, passwrd)

def spawn_telnet_session(argv, args, passwrd):
    print("spawing telnet session to [%s] for user [%s]" % (args.host, args.user))
    child = pexpect.spawnu('telnet -l %s %s' % (args.user, args.host))
    child.sendline("\n")
    #child.sendline("\n")
    #print(child.before)
    try:
        while True:
            index = child.expect(['(?i)password', 'login:'], timeout=15)
            if index == 0:
                print_console_op(child)
                child.sendline(passwrd)
                child.interact()
                break
            elif index == 1:
                print_console_op(child)
                child.sendline(args.user)
            else:
                print_console_op(child)
                sys.exit()
    except pexpect.TIMEOUT:
        print (' exception handler -- TIMEOUT!!!')
        sys.exit()

    # The rest is not strictly necessary. This just demonstrates a few functions.
    # This makes sure the child is dead; although it would be killed when Python exits.
    if child.isalive():
        print('Left interactve mode.')
        child.sendline('bye') # Try to ask ftp child to exit.
        child.close()
    # Print the final state of the child. Normally isalive() should be FALSE.
    if child.isalive():
        print('Child did not exit gracefully.')
    else:
        print('Child exited gracefully.')


def spawn_ssh_session(argv, args, passwrd):
    print("spawing scp session to [%s] for user [%s]" % (args.host, args.user))
    child = pexpect.spawnu('ssh %s@%s' % (args.user, args.host))

    try:
        while True:
            index = child.expect(['(?i)password', 'Are you sure you want to continue connecting', 'Enter your option :', 'Host key verification failed'], timeout=15)
            if index == 0:
                print_console_op(child)
                child.sendline(passwrd)
                child.interact()
                break
            elif index == 1:
                child.sendline('yes')
            elif index == 2:
                print_console_op(child)
                child.sendline('1')
                child.interact()
                break
            elif index == 3:
                update_ssh_know_host(child, args.host)
                if child.isalive():
                    child.close()
                spawn_ssh_session(argv, args, passwrd)
                break
            else:
                print_console_op(child)
                sys.exit()
    except pexpect.TIMEOUT:
        print (' exception handler -- TIMEOUT!!!')
        sys.exit()


# The rest is not strictly necessary. This just demonstrates a few functions.
# This makes sure the child is dead; although it would be killed when Python exits.
    if child.isalive():
        print('Left interactve mode.')
        child.sendline('bye') # Try to ask ftp child to exit.
        child.close()
# Print the final state of the child. Normally isalive() should be FALSE.
    if child.isalive():
        print('Child did not exit gracefully.')
    else:
        print('Child exited gracefully.')


if __name__ == "__main__":
    main(sys.argv[1:])
