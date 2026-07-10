# Testing e-mail (smtp)

Python script to test sending e-mail from shell

## Dependencies

```bash
apt update
apt install libnet-ssleay-perl libio-socket-ssl-perl
```

## Usage

Change the arguments used as you need.

```bash
./sendEmail.pl -f noreply@evertramos.com -u admin -m admin -t evert.ramos<AT>gmail.com -s yoursmtp.example.com -o tls=yes -xu stmp_user -xp smtp_password
```
