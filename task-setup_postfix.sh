#!/bin/bash

HOSTNAME=
MAILGUN_CONF=
MAILGUN_USER=
MAILGUN_PASS=
MAILGUN_DOMAIN=

POSTFIX_MAIN_CF=/etc/postfix/main.cf
POSTFIX_SASL_FILE=/etc/postfix/sasl_password

show_help() {
    cat << SHOW_HELP
Usage: $(basename $0) -c /path/to/mailgun.conf -hn hostname

    mailgun.conf content:

    mg_user=<mailgun username>
    mg_pass=<mailgun password>
    mg_domain=<mailgun domain>

    Other options:

    -h: Show this help and exit

SHOW_HELP
}

fexit() {
    echo "Oops: $@"
    show_help
    exit 1
}

while [ $# -gt 0 ]; do
    case $1 in
        -c|-config|--config)
            MAILGUN_CONF=$2
            shift
            shift
            ;;
            -h
        -h)
            show_help
            exit 0
            ;;
    esac
done

test -z $MAILGUN_CONF && fexit "Missing mailgun config file"
test -e $MAILGUN_CONF || fexit "Unable to find the mailgun config file"

source $MAILGUN_CONF
export $(cut -d= -f1 $MAILGUN_CONF)

echo "Setting installation options: "

echo -n " - main_mailer_type: " 
op1="select Satellite system"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type $op1" && echo "OK" || fexit "Can't set main_mailer_type"

echo -n " - mailname: " 
op2="string $HOSTNAME"
sudo debconf-set-selections <<< "postfix postfix/mailname $op2" && echo "OK" || fexit "Can't set mailname"

echo -n " - relayhost: " 
op3="string smtp.mailgun.org"
sudo debconf-set-selections <<< "postfix postfix/relayhost $op3" && echo "OK" || fexit "Can't set relayhost"

echo -n "Installing postfix: "
sudo apt-get install -y postfix >> ./apt-get-install-y-postfix.log 2>&1 && echo "OK" || fexit "Failed to install postfix"

echo -n "Configuring mailgun credentials to: $POSTFIX_SASL_FILE"
sasl_content="smtp.mailgun.org    $MAILGUN_USER@$MAILGUN_DOMAIN:$MAILGUN_PASS"
echo "$sasl_content" | sudo tee -a $POSTFIX_SASL_FILE > /dev/null && echo "OK" || fexit "Failed to setup smtp credentials"

sudo chmod 600  $POSTFIX_SASL_FILE
sudo postmap    $POSTFIX_SASL_FILE

sudo tee -a $POSTFIX_MAIN_CF > /dev/null <<MAIN_CF
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:$POSTFIX_SASL_FILE
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous
smtp_sasl_mechanism_filter = AUTH LOGIN
MAIN_CF

echo -n "Restarting postfix: "
sudo systemctl restart postfix && echo "OK" || echo "Failed"
