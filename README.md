# Automatic restic backups using systemd services and timers

## Restic

[restic](https://restic.net/) is a command-line tool for making backups, the right way. Check the official website for a feature explanation. As a storage backend, I recommend SFTP as restic works well with it, and it is (at the time of writing) very affordable for the hobbyist hacker!

Unfortunately restic does not come pre-configured with a way to run automated backups, say every day. However it's possible to set this up yourself using systemd/cron and some wrappers. This example also features email notifications when a backup fails to complete.

Here follows a step-by step tutorial on how to set it up, with my sample script and configurations that you can modify to suit your needs.


Note, you can use any of the supported [storage backends](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html). The setup should be similar but you will have to use other configuration variables to match your backend of choice.


## Set up

Tip: The steps in this section will instruct you to copy files from this repo to system directories. If you don't want to do this manually, you can use the Makefile:

```bash
$ git clone https://github.com/erikw/restic-systemd-automatic-backup.git
$ cd restic-systemd-automatic-backup
$ sudo make install
````

### 1. Configure your SFTP credentials locally
Put these files in `/etc/restic/`:
* `sftp_local_env.sh`: Fill this file out with your SFTP server settings etc. The reason for putting these in a separate file is that it can be used also for you to simply source, when you want to issue some restic commands. For example:
```bash
$ source /etc/restic/sftp_local_env.sh
$ restic snapshots    # You don't have to supply all parameters like --repo, as they are now in your environment!
````
* `sftp_pw.txt`: This file should contain the restic repository password. This is a new password what soon will be used when initializing the new repository. It should be unique to this restic backup repository and is needed for restoring from it.

### 2. Initialize remote repo
Now we must initialize the repository on the remote end:
```bash
source /etc/restic/sftp_local_env.sh
restic init
```

### 3. Script for doing the backup
Put this file in `/usr/local/sbin`:
* `restic_backup.sh`: A script that defines how to run the backup. Edit this file to respect your needs in terms of backup which paths to backup, retention (number of backups to save), etc.

Copy this file to `/etc/restic/backup_exclude` or `~/.backup_exclude`:
* `.backup_exclude`: A list of file pattern paths to exclude from you backups, files that just occupy storage space, backup-time, network and money.


### 4. Make first backup & verify
Now see if the backup itself works, by running

```bash
$ /usr/local/sbin/restic_backup_local.sh
$ restic snapshots
````

### 5. Backup automatically; systemd service + timer for local and offsite
Now we can do the modern version of a cron-job, a systemd service + timer, to run the backup every day!


Put these files in `/etc/systemd/system/`:
* `restic-backup@local.service`: A service that calls the backup script.
* `restic-backup@local.timer`: A timer that starts the backup every day.


Now simply enable the timer with:
```bash
$ systemctl start restic-backup@local.timer
$ systemctl enable restic-backup@local.timer
````

You can see when your next backup is scheduled to run with
```bash
$ systemctl list-timers | grep restic
```

and see the status of a currently running backup with

```bash
$ systemctl status restic-backup@local
```

or start a backup manually

```bash
$ systemctl start restic-backup@local
```

You can follow the backup stdout output live as backup is running with:

```bash
$ journalctl -f -u restic-backup@local.service
````

(skip `-f` to see all backups that has run)



### 6. Email notification on failure
We want to be aware when the automatic backup fails, so we can fix it. Since my laptop does not run a mail server, I went for a solution to set up my laptop to be able to send emails with [postfix via my Gmail](https://easyengine.io/tutorials/linux/ubuntu-postfix-gmail-smtp/). Follow the instructions over there.

Put this file in `/usr/local/sbin`:
* `systemd-email`: Sends email using sendmail(1). This script also features time-out for not spamming Gmail servers and getting my account blocked.

Put this files in `/etc/systemd/system/`:
* `status-email-user@.service`: A service that can notify you via email when a systemd service fails. Edit the target email address in this file.

As you maybe noticed already before, `restic-backup@local.service` is configured to start `status-email-user.service` on failure.


### 7. Optional: automated backup checks
Once in a while it can be good to do a health check of the remote repository, to make sure it's not getting corrupt. This can be done with `$ restic check`.

There are some `*-check*`-files in this git repo. Install these in the same way you installed the `*-backup*`-files.


## Cron?
If you want to run an all-classic cron job instead, do like this:

* `etc/cron.d/restic`: Depending on your system's cron, put this in `/etc/cron.d/` or similar, or copy the contents to $(sudo crontab -e). The format of this file is tested under FreeBSD, and might need adaptions depending on your cron.
* `usr/local/sbin/cron_mail`: A wrapper for running cron jobs, that sends output of the job as an email using the mail(1) command.
