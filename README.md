Experiments with PocketCHIP
===========================

Herein lies rubbish I've written while messing around with the rather fabulous
[pocketCHIP][1]. Some of it might even work.

In general, I compile stuff on the device itself, mostly because I'm too
lazy to set up a cross compiler. To do that, I edit the files on the device
over ssh and use gcc to do the compiling.

To setup sshd on the device:

1. Open the terminal app on the device.
2. Update your apt sources: `sudo apt-get update`
3. Optionally upgrade everything: `sudo apt-get upgrade`
4. Install the ssh server: `sudo apt-get install openssh-server`

The server should be installed and running now. In order to connect to it from
another computer you have to find out its IP address. The easiest way to
do this is with the command: `ip addr show wlan0`. You'll see something
like this:

    chip@chip:~/Development/pocketchip-playing$ ip addr show wlan0
    4: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
        link/ether 7c:c7:09:e0:b3:59 brd ff:ff:ff:ff:ff:ff
        inet 192.168.1.104/24 brd 192.168.1.255 scope global dynamic wlan0
           valid_lft 84753sec preferred_lft 84753sec
        inet6 fe80::7ec7:9ff:fee0:b359/64 scope link 
           valid_lft forever preferred_lft forever

The address you want is just after the word `inet` and before `/24`. In this
case it's `192.168.1.104`. Now you can ssh to that address from your main
machine. I'm assuming you have MacOS or Linux installed here and have ssh
available from the command line:

1. `ssh chip@192.168.1.104`
2. Enter the default password `chip`
3. Optionally but **highly** recommended, change the default password with the `passwd` command.

If you're using Windows, checkout PuTTY as a good SSH client to use.

Next, install some development tools. From the chip SSH session:

1. `sudo apt-get install gcc gdb make`
2. Optionally install git if you want to use that for version control: `sudo apt-get install git`

Finally, you have to decide how you want to edit the source files. The simplest
way is to use `nano` on the device:

1. From the ssh session: `nano main.c`
2. Enter a simple C program:
    #include <stdio.h>

    int main(int argc, char* argv[]) {
        printf("Hello, world!\n");
        return 0;
    }
3. Compile the program: `gcc --std=c11 -ggdb main.c -o main`
4. Run the compiled program: `./main`

You should see a salutatory message displayed. Now you can go and program
anything!

When coding on the chip I like to use [Sublime Text][2] to edit the source files
on my local machine and mount the chip  using sshfs. That allows me to treat the chip
as a local directory, with me only switching to the terminal to compile and run
the program. If you want to be extra fancy, you can setup a utility on the chip
such as [rerun][3] to watch the source file(s) and then automatically call `make`
when they change. That lets you get an almost scripting like experience for
coding on it which is pretty nifty.






[1]: https://getchip.com/pages/pocketchip
[2]: http://www.sublimetext.com
[3]: https://github.com/alexch/rerun
