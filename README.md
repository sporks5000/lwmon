# Purpose
LWmon is a command-line tool for monitoring up-time of servers and websites with minimal effort. It outputs colored text showing data for multiple monitoring jobs to a single terminal window, allowing the user to be constantly aware of the status of each monitoring job without having to put forth too much effort or look for details in multiple places.

Its output is based on the notion that the human eye is drawn to change. For each check it performs, it outputs a line of text with details on success or failure, and when that status changes from one check to the next, the color of the output changes to make it quickly visible that something is different. As a result, a single terminal window taking up minimal screen real estate can be used to monitor multiple items at once, and alert an end user when something has changed.

# Limitations and Requirements

This script has been tested on Debian, Mint, and CentOS 6, and 7 without issues. It's author can make no guarantees for other operating systems. It's functionality requires the presence of Bash, Perl, and various standard Linux command line utilities.

# Installation
Run the following to install LWmon:

```
git clone https://github.com/sporks5000/lwmon.git
./lwmon/install.sh
```

LWmon can do the following:
* Monitor various services on a remote server
  * Check a website to verify that it's loading as expecting by making a request for its content, and then checking to ensure that the response includes specified strings of text
  * Check whether or not a server is pinging
  * Keep track of the load average on a remote server (via SSH control sockets)
  * Check DNS on a server by regularly performing dig requests against it
* Send email notifications when the status of a monitoring job has changed
* Keep track of the timestamps of when the status of a monitoring job has changed, as well as the percentage of successes vs. failures

# Master / Child Model
LWmon uses a master process and child processes in order to output data; this allows it to output information from multiple jobs in a single terminal window. If you need to start additional monitoring jobs, run the command to start them in a separate terminal window, and the output from the new jobs you've created will output in the original terminal window alongside any previously existing jobs.

# How To Make It Do The Things
LWmon has a number of command line options to start monitoring jobs, as well as a system of menus to modify and view data related to existing jobs. You can read more about them by running the following:

```
./lwmon/lwmon.sh --help
```

If there are no previously running LWmon monitoring jobs, the first job created will output the results of the checks it performs in the terminal session in which it is opened. Additional jobs opened from the command line in other terminal windows will output to the session of the original job as well - thus only a small amount of desktop space can be used to monitor multiple things simultaneously

## Monitoring A URL
When monitoring a URL, LWmon will run in a loop, at intervals (set by the user) running a curl against the URL in question and then checking the result for a specific string of text. If the string of text is present in the result, it will report as a success, otherwise it will report as a failure. The best way to find an appropriate string of text is to run "curl -L" against what ever URL you're monitoring, and select something from what's present - preferably select a portion of the site that isn't likely to disappear if updates are made to the current content (For example - text from headers and footers on a WordPress site are good things to choose from, where as text from within an article on the front page might disappear or change before too long)

### Examples

```
./lwmon.sh --url domain.com --string "Other Side of the Moon"
```

The above will repeatedly (the default is every 30 seconds, but you can change this) curl the URL domain.com, and return successful if the string "Other Side of the Moon" is present.

```
./lwmon.sh --url tacobell.com --string "taco time ALL the time" --ip-address 72.52.228.74 --seconds 30 --check-timeout 15 --user-agent
```

The above will curl for tacobell.com specifically at IP address 72.52.228.74 (regardless where DNS or hosts files might be pointing) every 30 seconds. If the curl command doesn't get a response after 15 seconds, it will fail automatically (the default is 10 seconds), and it will pretend to use the google chrome user agent rather than the default LWmon user agent.

## Monitoring Ping
Using LWmon to monitor the ping of a server is beneficial over just using the "ping" command, because 1) it produces output indicating whether the ping is a success or failure (rather than just for successes), and 2) it provides timestamps. With this, for example, you can know the exact timestamps of when a server stopped pinging and then started pinging again during the course of a reboot.

### Examples

```
./lwmon.sh --ping 72.52.228.74 --seconds 2
```

The above will ping IP 72.52.228.74 every two seconds, and report whether the ping succeeds or fails.

```
./lwmon.sh --ping domain.com --seconds 2 --outfile /var/log/lwmon.output.log --mail user@domain.com --mail-delay 3 --nsr 15 --nsns 5
```

The above will ping the domain "domain.com" every two seconds. Rather than outputting to the window where the master LWmon process is running, the monitoring job will output the results of each check to the file "/var/log/LWmon.output.log" (assuming the user it's running as has write access). If at any point in time, three pings in a row fail, an email will be sent to user@domain.com (using the system's mail binary) with information about the status of the job (similarly, if the pings have been failing for a while, but then three succeed in a row, an email will be sent with those details). In addition to this, if out of any fifteen consecutive pings, five of them are failures (but never three in a row, the number specified to trigger an e-mail otherwise), an e-mail will be sent indicating that this is the case.

## Monitoring Remote Load via SSH
LWmon can be used to monitor load on a remote server (or locally). Instead of outputting whether a check passed or failed, the script will output the load. The user can use the "--load-ps" and "--load-fail" flags to cause color changes to the text that's being output in order to better grab their attention if the load goes higher than they would like.

Monitoring load requires the presence of an ssh control socket on your '''local''' machine in order to access the '''remote''' machine. Don't worry, the script will tell you how to set this up, similar to below:

```
user@desktop [~]# ./lwmon.sh --ssh-load remote.domain.com --user username --port 255 --load-ps 0.10 --load-fail 0.20

There doesn't appear to be an SSH control socket open for this server. Use the following command to SSH into this server (you'll probably want to do this in another window, or a screen), and then try starting the job again:

ssh -o ControlMaster=auto -o ControlPath="~/.ssh/control:%h:%p:%r" -p 255 username@remote.domain.com

Be sure to exit out of the master ssh process when you're done monitoring the remote server.
```

### Examples

```
./lwmon.sh --ssh-load localhost --load-ps 1.25 --load-fail 2.45
```

The above will output the load locally, reporting as a partial success if the one minute load average is 1.25 or above, and a failure if the one minute load average is 2.45 or above.

```
./lwmon.sh --ssh-load domain.com --user username --port 22 --load-ps 4 --load-fail 8 --seconds 5 --ctps 6
```

The above will connect to domain.com on port 22 and output the load on that server every five seconds. If the load is 4 or higher, the output colors will indicate that the check was a partial success; if the load is 8 or higher, the output colors will indicate that the check is a failure. If for some reason the check takes six seconds or more to complete but otherwise would be counted as a success, the color of the output will only indicate a partial success, thus alerting the user that there might be something amiss.

## Monitoring DNS Services
LWmon can be used to monitor DNS services on a server. This was very useful back in 2013 when DNS was one of the first things that would routinely go down on an overloaded cPanel server. It's not as useful now, but the functionality is still present. LWmon will make a DNS query to the remote server for a domain known to have DNS records on the server (as provided by the user). If a result is returned, the check is considered a success.

### Examples

```
./lwmon.sh --dns host.domain.com --domain test-domain.com --seconds 30
```

The above will run a dig at host.domain.com for the domain "test-domain.com" every thirty seconds. So long as it gets a result, the check will be considered successful.

```
./lwmon.sh --dns host.domain.com --domain domain.com --record-type txt --check-result "v=spf1 +a +mx" --job-name "domain.com - ticket 1234567"
```

The above will run a dig at host.domain.com for "txt" records for the domain "domain.com". Only if the results contain the string "v=spf1 +a +mx" will the check be considered successful. The job name that's reported in the LWmon output will be "domain.com - ticket 1234567"

## Additional Command Line Flags
For additional information on the command line flags that LWmon can accept, run the following:

```
./lwmon.sh --help flags
```

# Modifying Existing Jobs

When the user runs `./lwmon.sh --modify`, they are given a numbered list of currently running jobs. When they select a number from the list, they are given options for how for the job in question - things such as "Kill this process" and "Output the commands to reproduce this job".

Worthy of additional explanation is option number 3: "Directly edit the parameters file". This option will allow you to make changes to settings for an existing job by editing the parameters that were specified by the command line flags when the job was created.

For details on all the parameters present within this file and what they do, you can run the following:

```
./lwmon.sh --help params-file
```

# Configuration File

LWmon includes a configuration file that can be used to modify its default behavior. When LWmon is run for the first time it will generate a configuration file named lwmon.conf in the same directory as lwmon.sh. This file should include all of the necessary details on what the directives therein accomplish.

# Reporting Bugs, Feature Requests

If you notice any bugs or behavior that you don't believe is expected, don't hesitate to submit an issue at one of the LWmon git repositories listed below, or to email acwilliams@liquidweb.com. He's a pretty cool guy, and he gets super excited when people like scripts he's written enough to give him feedback on them.

There are two git repositories for LWmon:
* https://github.com/sporks5000/lwmon (public)
* https://git.liquidweb.com/acwilliams/lwmon (private)

