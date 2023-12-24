# simple_linux_selfcontrol

Simple script that rewites /etc/hosts to block websites for a given time)
Yeeeeah, I know, any linux user can bypass it, find seek and kill process, but it's will  pretend unconscious use of time-killers

Usage:
```
sudo ./self_control.sh 60 www.youtube.com www.facebook.com www.twitter.com
```
Where:

1. Time in minutes
2. List of websites to block

TODO:

1. Add nohup check that hosts wasnt unblocked
2. restart after system restart
3. hide process from easiest ways to kill it
4. checl sign
