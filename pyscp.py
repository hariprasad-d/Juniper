#!/usr/bin/env python

from __future__ import absolute_import
from __future__ import print_function
from __future__ import unicode_literals

import pexpect
import sys, argparse, getpass


def print_console_op(child):
    sys.stdout.write (child.before)
    sys.stdout.write (child.after)
    
def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("file", help="file list", nargs='+')
    parser.add_argument("host", help="host ip/name", default='10.204.96.200')
    parser.add_argument("-u", help="user", default='root')
    parser.add_argument("-p", help="path", default="/var/tmp/")
    parser.add_argument("-get", help="get files from remote, default mode put files to remote",
                                default=False, action='store_true')
    args = parser.parse_args()

    print("spawing scp session to [%s] for user [%s]" % (args.host, args.u))
    print("Remote Path [%s]" % args.p)

    print(args.get)

    if args.get is True:
        spn_str = 'scp %s@%s:%s%s .' % (args.u, args.host, args.p,  args.file[0])
    else:
        files = " ".join(str(x) for x in args.file)
        spn_str = 'scp %s %s@%s:%s' % (files, args.u, args.host, args.p)

    print(spn_str)

    if args.u == 'regress':
        passwrd = 'MaRtInI'
    elif args.u == 'root':
        passwrd = 'Embe1mpls'
    elif args.u == 'hprasad':
        passwrd = 'op12OP!@'
    else:
        passwrd = getpass.getpass('Password:')

    #child = pexpect.spawnu('scp %s %s@%s:%s' % (files, args.u, args.host, args.p))
    child = pexpect.spawnu(spn_str, timeout=None)
    try:
        while True:
            index = child.expect(['(?i)password', 'Are you sure you want to continue connecting'], timeout=None)
            if index == 0:
                print_console_op(child)
                child.sendline(passwrd)
                i = child.expect(['[hprasad@* ~]$ ', pexpect.EOF])
                if  i == 1 or i == 0:
                    sys.stdout.write (child.before)
                    break
                else:
                    print('OOhhh!! Code just dropped me Here, without any VISA!!!')
                    print("debug information:")
                    print(str(child))

                sys.stdout.flush()
                break
            elif index == 1:
                child.sendline('yes')
            else:
                print_console_op(child)
                sys.exit()
    except pexpect.TIMEOUT:
        print (' exception handler -- TIMEOUT!!!')
        sys.exit()


# At this point the script is running again.
    print('Left interactve mode.')

# The rest is not strictly necessary. This just demonstrates a few functions.
# This makes sure the child is dead; although it would be killed when Python exits.
    if child.isalive():
        child.sendline('bye') # Try to ask ftp child to exit.
        child.close()
# Print the final state of the child. Normally isalive() should be FALSE.
    if child.isalive():
        print('Child did not exit gracefully.')
    else:
        print('Child exited gracefully.')


if __name__ == "__main__":
    main(sys.argv[1:])
