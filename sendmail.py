"""
Send mail
"""
import smtplib
import time
import getpass
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
import argparse

#
# Global variables, change as required
g_from_adr = 'z5alert@zakipoint.com'
g_to_adrs = ['abc@gmail.com', 'xyz@a2zanalytics.com']
#
# No modify zone frome here
def getTimestamp():
    return str(time.strftime("%Y-%m-%d %H:%M:%S "))

def parseArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument('smtp_host', action="store")
    parser.add_argument('port', action="store", type=int)
    parser.add_argument('username', action="store")
    parser.add_argument('password', action="store")
    parser.add_argument('mail_file_path', action="store")
    parser.add_argument('mail_subject', action="store")
    args = parser.parse_args()
    return args

def read_mailfile(mfile):
    content = []
    try:
        with open(mfile, 'r') as content_file:
            for line in content_file.readlines():
                content.append(line)
        bstr = ''.join(content)
    except Exception, err:
        return "Error reading email file. " + str(err)
    return bstr

def main():
    args = parseArgs()
    smtp_adr = args.smtp_host
    smpt_port = args.port
    username = args.username
    password = args.password
    mail_file_abs_path = args.mail_file_path
    mail_subject = args.mail_subject
    #
    # login with ssl
    try:
        server = smtplib.SMTP_SSL(smtp_adr, smpt_port)
        server.login(username, password)
    except Exception, e:
        print getTimestamp() + "Error occurred while connecting to smtp server"
        exit(1)
        return
    email_msg = MIMEMultipart()
    email_msg['From'] = g_from_adr
    email_msg['To'] = ", ".join(g_to_adrs)
    email_msg['Subject'] = mail_subject

    mail_file_content = read_mailfile(mail_file_abs_path)
    body = ("\n"
            "{0:s}\n"
            "\n"
            " Note:\n"
            " This is an automatically triggered email and may contain confidential information.\n"
            " If you have received this message in error, please notify the sender and delete the message.\n"
            "\n"
            " Thank you\n"
            "").format(mail_file_content)
    email_msg.attach(MIMEText(body, 'plain'))
    text = email_msg.as_string()
    try:
        server.sendmail(g_from_adr, g_to_adrs, text)
        server.quit()
    except Exception, err:
        print getTimestamp() + 'Sending email failed.'
if __name__ == "__main__":
    main()
