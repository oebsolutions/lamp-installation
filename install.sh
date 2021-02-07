#!/bin/bash


# GLOBAL PARAMETERS
SCRIPT_NAME="Oebs LAMP installation script for ubuntu 20.04"
SCRIPT_VERSION="v1.0"
MYSQL_OLD_ROOT_PASSWORD=''
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
MYSQL_CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
PHP_CONFIG_FILE="/etc/php/7.4/apache2/php.ini"
APACHE_CONFIG_FILE="/etc/apache2/apache2.conf"
MODSECURITY_CONFIG_FILE="/etc/apache2/mods-enabled/security2.conf"


# DO NOT CHANGE BELOW
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
NC='\033[0m'
WHITE='\033[1;37m'

MYSQL_NEW_ROOT_PASSWORD=''
SSH=''
SSH_SERVICE=''
APACHE2=''
APACHE2_SERVICE=''
APACHE2_CONFIG=''
PHP=''
PHP_CONFIG=''
MYSQL=''
MYSQL_SERVICE=''
MYSQL_CONFIG=''
MYSQL_CREATE=''
MYSQL_CHANGE_ROOT_PASSWORD=''




PHP_VERSION='Not installed'
APACHE_VERSION='Not installed'
MYSQL_VERSION='Not installed'

MYSQL_DATABASE_NAME=''
MYSQL_USER_NAME=''
MYSQL_USER_PASSWORD=''
MYSQL_USER_HOST=''


get_version(){
    
    php=$(php -v 2>/dev/null) 

    if [[ "$php" != "" ]]
    then
        PHP_VERSION=$(php -v|sed 1q|awk '{print $2}') 
    fi
    
    mysql=$(mysql -V 2>/dev/null)

    if [[ "$mysql" != "" ]]
    then
        MYSQL_VERSION=$(mysql -V|sed 1q|awk '{print $3}') 
    fi

    apache=$(apache2 -v 2>/dev/null)

    if [[ "$apache" != "" ]]
    then
        APACHE_VERSION=$(apache2 -v|sed 1q|awk '{print $3}') 
    fi

}


create_mysql_user(){
    q1="CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE_NAME CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
    q2="CREATE USER IF NOT EXISTS '$MYSQL_USER_NAME'@'$MYSQL_USER_HOST' IDENTIFIED BY '$MYSQL_USER_PASSWORD';"
    q3="GRANT ALL ON $MYSQL_DATABASE_NAME.* TO '$MYSQL_USER_NAME'@'$MYSQL_USER_HOST';"
    q4="FLUSH PRIVILEGES;"


    get_version


    if [[ "$MYSQL_VERSION" != "Not installed" ]]
    then
        sql="${q1}${q2}${q3}${q4}"
        mysql -u root -p$MYSQL_ROOT_PASSWORD -e "$sql"
        echo -e "${LIGHTGREEN} Database: $MYSQL_DATABASE_NAME ${NC}"
        echo -e "${LIGHTGREEN} User name: $MYSQL_USER_NAME ${NC}"
        echo -e "${LIGHTGREEN} User password: $MYSQL_USER_PASSWORD ${NC}"
        echo -e "${LIGHTGREEN} Successfully created. ${NC}"
    else
        echo -e "${LIGHTRED} Install mysql first. ${NC}"
    fi

}

change_root_password(){

    q1="UPDATE mysql.user SET plugin = 'caching_sha2_password' WHERE User = 'root';"
    q2="FLUSH PRIVILEGES;"
    q3="ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_NEW_ROOT_PASSWORD';"
    q4="FLUSH PRIVILEGES;"

    sql="${q1}${q2}${q3}${q4}"

    get_version


    if [[ "$MYSQL_VERSION" != "Not installed" ]]
    then
        
        mysql -u root -p$MYSQL_OLD_ROOT_PASSWORD -e "$sql"
        MYSQL_OLD_ROOT_PASSWORD="$MYSQL_NEW_ROOT_PASSWORD"
        echo -e "${LIGHTGREEN} Root password has changed. ${NC}"
        MYSQL_CHANGE_ROOT_PASSWORD='OK'
    else
        echo -e "${LIGHTRED} Install mysql first. ${NC}"
    fi

}

grant_all(){

    q1 = "GRANT ALL ON *.* TO '$MYSQL_USER_NAME'@'$MYSQL_USER_HOST';"
    q2 = "FLUSH PRIVILEGES;"

    get_version


    if [[ "$MYSQL_VERSION" != "Not installed" ]]
    then
        sql="${q1}${q2}"
        mysql -u root -p$MYSQL_ROOT_PASSWORD -e "$sql"
        echo -e "${LIGHTGREEN} $MYSQL_USER_NAME is now in GOD mode . ${NC}"
    else
        echo -e "${LIGHTRED} Install mysql first. ${NC}"
    fi
}


get_version

select_option(){
    clear
    case $key in
        1)
            # insert a blank line if the file is empty
            if [ ! -s $SSH_CONFIG_FILE ]; then echo "" > $SSH_CONFIG_FILE; fi	
            

            # remove the following lines
            sed -i '/----------------------------/d' $SSH_CONFIG_FILE
            sed -i '/$SCRIPT_NAME/d' $SSH_CONFIG_FILE

            sed -i '/PermitRootLogin/d' $SSH_CONFIG_FILE
            sed -i '/PermitEmptyPasswords/d' $SSH_CONFIG_FILE
            sed -i '/PubkeyAuthentication/d' $SSH_CONFIG_FILE
            sed -i '/PasswordAuthentication/d' $SSH_CONFIG_FILE
            sed -i '/X11Forwarding/d' $SSH_CONFIG_FILE

            sed -i '/ClientAliveInterval/d' $SSH_CONFIG_FILE
            sed -i '/ClientAliveCountMax/d' $SSH_CONFIG_FILE


            # edd the following lines to the end of file
            echo "# ----------------------------" >> $SSH_CONFIG_FILE
            echo "# $SCRIPT_NAME $SCRIPT_VERSION" >> $SSH_CONFIG_FILE

            sed -i '$ a PermitRootLogin without-password' $SSH_CONFIG_FILE
            sed -i '$ a PermitEmptyPasswords no' $SSH_CONFIG_FILE
            sed -i '$ a PubkeyAuthentication yes' $SSH_CONFIG_FILE
            sed -i '$ a PasswordAuthentication no' $SSH_CONFIG_FILE
            sed -i '$ a X11Forwarding no' $SSH_CONFIG_FILE

            sed -i '$ a ClientAliveInterval 120' $SSH_CONFIG_FILE
            sed -i '$ a ClientAliveCountMax 720' $SSH_CONFIG_FILE

            SSH='OK';;
        2)
            sudo service ssh restart
            SSH_SERVICE='OK';;
        3)	
            sudo apt-get update
            sudo apt install -y apache2
            sudo a2enmod rewrite
            APACHE2='OK';;

        31)
            echo -e "install apache2 headers (y/n) ?"
            read VAR

            if [[ $VAR == 'y' ]]
            then
                sudo a2enmod headers
                sudo service apache2 restart
            else
                exit 1
            fi

            echo -e "install apache2 ModSecurity module (y/n) ?"
            read VAR
            if [[ $VAR == 'y' ]]
            then
                sudo apt instal libapache2-mod-security2 -y
                sudo service apache2 restart
            else
                exit 1
            fi


            echo -e "apply ModSecurity CSR rules from github (y/n) ? "
            read VAR
            if [[ $VAR == 'y' ]]
            then
                rm -rf /usr/share/modsecurity-crs
                git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git /usr/share/modsecurity-crs
                
                echo "" > $MODSECURITY_CONFIG_FILE
                # add the following lines to the end of file
                sed -i '$ a <IfModule security2_module>' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         # Default Debian dir for modsecuritys persistent data' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         SecDataDir /var/cache/modsecurity' $MODSECURITY_CONFIG_FILE
                
                sed -i '$ a         # Include all the *.conf files in /etc/modsecurity.' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         # Keeping your local configuration in that directory' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         # will allow for an easy upgrade of THIS file and' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         # make your life easier' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         IncludeOptional /etc/modsecurity/*.conf' $MODSECURITY_CONFIG_FILE
                
                sed -i '$ a         # Include OWASP ModSecurity CRS rules if installed' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         IncludeOptional /usr/share/modsecurity-crs/*.load' $MODSECURITY_CONFIG_FILE
                sed -i "$ a         # Extra CRS rules added by $SCRIPT_NAME $SCRIPT_VERSION" $MODSECURITY_CONFIG_FILE
                sed -i '$ a         IncludeOptional /usr/share/modsecurity-crs/*.conf' $MODSECURITY_CONFIG_FILE
                sed -i '$ a         IncludeOptional /usr/share/modsecurity-crs/rules/*.conf' $MODSECURITY_CONFIG_FILE
                sed -i '$ a </IfModule>' $MODSECURITY_CONFIG_FILE
            else
                exit 1
            fi



            echo -e "apply some security configuration to  apache2.conf (y/n) ?"
            read VAR
            if [[ $VAR == 'y' ]]
            then

                # insert a blank line if the file is empty
                if [ ! -s $APACHE_CONFIG_FILE ]; then echo "" > $APACHE_CONFIG_FILE; fi	
                

                # remove the following lines
                sed -i '/----------------------------/d' $APACHE_CONFIG_FILE
                sed -i '/$SCRIPT_NAME/d' $APACHE_CONFIG_FILE

                sed -i '/ServerSignature/d' $APACHE_CONFIG_FILE
                sed -i '/ServerTokens/d' $APACHE_CONFIG_FILE
                sed -i '/Header set X-XSS-Protection "1; mode=block"/d' $APACHE_CONFIG_FILE
                sed -i '/Header set X-Content-Type-Options nosniff/d' $APACHE_CONFIG_FILE
                sed -i '/Header set Referrer-Policy "no-referrer"/d' $APACHE_CONFIG_FILE


                # add the following lines to the end of file
                echo "# ----------------------------" >> $APACHE_CONFIG_FILE
                echo "# $SCRIPT_NAME $SCRIPT_VERSION" >> $APACHE_CONFIG_FILE

                sed -i '$ a ServerSignature Off' $APACHE_CONFIG_FILE
                sed -i '$ a ServerTokens Prod' $APACHE_CONFIG_FILE
                sed -i '$ a Header set X-XSS-Protection "1; mode=block"' $APACHE_CONFIG_FILE
                sed -i '$ a Header set X-Content-Type-Options nosniff' $APACHE_CONFIG_FILE
                sed -i '$ a Header set Referrer-Policy "no-referrer"' $APACHE_CONFIG_FILE

                sed -i '$ a <IfModule security2_module>' $APACHE_CONFIG_FILE
                sed -i '$ a     SecRuleEngine on' $APACHE_CONFIG_FILE
                sed -i '$ a     ServerTokens Min' $APACHE_CONFIG_FILE
                sed -i '$ a     SecServerSignature " "' $APACHE_CONFIG_FILE
                sed -i '$ a </IfModule> ' $APACHE_CONFIG_FILE
                
            else
                exit 1
            fi

            APACHE2_CONFIG='OK';;


        4)	
            sudo service apache2 restart
            APACHE2_SERVICE='OK';;
        5)	
            sudo apt-get update
            sudo apt install -y php libapache2-mod-php php-mysql php-cli php-common php-curl php-gd php-json php-mbstring php-mysql php-xml php-soap php-redis php-zip php-dev
            PHP='OK';;
        6)	
            sudo apt-get update
            sudo apt-get install -y mysql-server
            MYSQL='OK';;
        7)	
            sudo service mysql restart
            MYSQL_SERVICE='OK';;
        8)
            echo -e "${WHITE}Enter existing root password ${RED}(leave blank after fresh mysql installation): "
            read MYSQL_OLD_ROOT_PASSWORD
            echo -e "${WHITE}Enter new root password: " 
            read MYSQL_NEW_ROOT_PASSWORD
            change_root_password;;
        9)
            read -p "Enter mysql database name: " MYSQL_DATABASE_NAME
            read -p "Enter mysql user name: " MYSQL_USER_NAME
            read -p "Enter mysql host name (% or localhost, w/o quotes): " MYSQL_USER_HOST
            read -p "Enter mysql user password: " MYSQL_USER_PASSWORD
            read -p "Enter mysql root password: " MYSQL_ROOT_PASSWORD
            create_mysql_user
            MYSQL_CREATE='OK';;
        10)	
            sed -i '/bind-address/d' $MYSQL_CONFIG_FILE
            echo "# $SCRIPT_NAME $SCRIPT_VERSION" >> $MYSQL_CONFIG_FILE
            sed -i '$ a bind-address    =   0.0.0.0' $MYSQL_CONFIG_FILE
            MYSQL_CONFIG='OK';;
        11)
            
            sudo apt update
            sudo apt upgrade

            sudo apt install wireguard
            sudo apt install openresolv
            sudo apt install resolvconf

            
            # To bring the WireGuard interface at boot time run the following command:
            systemctl start wg-quick@wg0
            systemctl enable wg-quick@wg0



            # for NAT to work
            sudo nano /etc/sysctl.d/wg.conf
            net.ipv4.ip_forward = 1
            net.ipv6.conf.all.forwarding = 1

            sudo sysctl --system;;

        12)	
            sed -i '/$SCRIPT_NAME/d' $PHP_CONFIG_FILE

            sed -i '/max_execution_time/d' $PHP_CONFIG_FILE
            sed -i '/memory_limit/d' $PHP_CONFIG_FILE

            echo "# $SCRIPT_NAME $SCRIPT_VERSION" >> $PHP_CONFIG_FILE

            sed -i '$ a max_execution_time = 86400' $PHP_CONFIG_FILE
            sed -i '$ a memory_limit = 512M' $PHP_CONFIG_FILE

            PHP_CONFIG='OK';;
        13)	
            exit 1;;
        *) ;;
    esac
    show_menu
}


show_logo(){
    echo -e "       .:+osyyso+:.             ':+osyyyyyyyyyyyyy 'yyyyyyyyyyyyyso/-'             .:+ssyyyyyyyyyyyyo"
    echo -e "    '/yy+:......:+yy/'        :sho:-..............  ..............-:ohs:        '+yy+:..............'"
    echo -e "   /ho.'/oyyssyyo/'.oh/     -yy:':oyysssssssssssss 'sssssssssssssyyo:':yy-     /ho.'/syyssssssssssss+"
    echo -e "  oh: +ho-.-::-.-oh+ :ho   :h+ :ys:..:::::::::::::  :::::::::::::..:yy:'oh:   oh: +ho-.-:///////////:"
    echo -e " :d/ oh-'oho//oho'-ho /d: 'hs :d+ /ys+//////////// '////////////+sy: +d: sh' :d/ oh-'+ho////////////:"
    echo -e " sd'.do +d-    -d+ od.'ds /d: yh -d+                              od. hy :d: od''do +d-              "
    echo -e " sd -d+ sd'    'ds +d- ds :d: yh'.ho'                            'sh.'hs /d- +d.'hs :h/'             "
    echo -e " sd -d+ sd'    'ds +d- ds 'yy'-ho'-ssooooooooooooo 'oooooooooooooso-.sh.'yy  .ho /h+':ssoooooooooooo+"
    echo -e " sd -d+ sd'    'ds +d- ds  -ys..sy+---::::::::::::  ::::::::::::---+yo..sy.   :ho'-ss+---------------"
    echo -e " sd -d+ sd'    'ds +d- ds   .oy+.-/ossssssssssssss 'sssssssssssssso/-.+yo'     -sy/.-/osssssssssssss+"
    echo -e " sd -d+ sd'    'ds +d- ds     .+sso/:-------------  -------------:/oss+.         -+ss+/:-------------"
    echo -e " /+ '+- /+      +/ -+' +/        .-/++++++++++++++ '++++++++++++++/-.              '.-/+++++++++++++/"
    echo -e " :+ '+- :+      +: -+' +:        .-:/+++++++++++++ '+++++++++++++/:-'        /+++++++++++++/-.'      "
    echo -e " sd -d+ sd'    'ds +d- ds     ./sso/::::::::::::::  ::::::::::::::+oss/.     -------------:/+sso-    "
    echo -e " sd -d+ sd'    'ds +d- ds   'oy+--:+ssssssssssssss 'ssssssssssssss+:--oy+'   +ssssssssssssso/-./ys-  "
    echo -e " sd -d+ sd'    'ds +d- ds  .ys..oyo:--------------  --------------:oyo..yy.  ---------------/ss:'+h/ "
    echo -e " sd -d+ sd'    'ds +d- ds 'yy'-hs..oyooooooooooooo 'oooooooooooooyo..sy.'yy  /ooooooooooooss:'/h/ +h-"
    echo -e " sd -d+ sd'    'ds +d- ds :d/ sh'.hs'                            .sh.'hs /d-              '/d/ sh''do"
    echo -e " sd .d+ +d.    .d+ +d.'ds /d: yh -d+                              +d- hy :d:               -d+ od.'ds"
    echo -e " /d: sh-'oho//oho'-hs :d/ .ho /d/ /hs/::::::::::::  ::::::::::::/sy/ +d: sh' :////////////oho'-hs /d:"
    echo -e "  oh-'+h+-.://:.-+h+'-ho   /d+ :hs-'-///////////// '////////////:-':sh: +h:  :///////////:-'-+h+':ho "
    echo -e "   +ho..+sysoosys+..oh+     :ys-':oyysoooooooooooo 'oooooooooooosyyo:'-yy-   +ssssssssssssyys/..oh/  "
    echo -e "    .+ys/-......-/sy+.       '/yy+:...............  ...............:+ys/'    '..............:+yy+'   "
    echo -e "       ./osyyyyso/.             ':+syyyyyyyyyyyyyy''yyyyyyyyyyyyyys+:'       oyyyyyyyyyyyyss+/.      "
    echo -e ""
}

show_menu(){
    get_version
    echo "###################################################################################"
    echo -e "$SCRIPT_NAME"
    echo -e "${CYAN} ------------------ MENU -----------------------${NC}"
    echo -e "${CYAN} 1 Secure configuration for ssh ${LIGHTGREEN} $SSH ${NC}"
    echo -e "${CYAN} 2 Restart ssh service ${LIGHTGREEN} $SSH_SERVICE ${NC}"
    echo -e "${CYAN} 3 Install apache2 ${YELLOW} $APACHE_VERSION  ${LIGHTGREEN} $APACHE2 ${NC}"
    echo -e "${CYAN} 31 Secure configuration for apache2 ${LIGHTGREEN} $APACHE2_CONFIG ${NC}"
    echo -e "${CYAN} 4 Restart apache2 ${LIGHTGREEN} $APACHE2_SERVICE ${NC}"
    echo -e "${CYAN} 5 Install php ${YELLOW} $PHP_VERSION ${LIGHTGREEN} $PHP ${NC}"
    echo -e "${CYAN} 6 Install mysql ${YELLOW} $MYSQL_VERSION ${LIGHTGREEN} $MYSQL ${NC}"
    echo -e "${CYAN} 7 Restart mysql ${LIGHTGREEN} $MYSQL_SERVICE ${NC}"
    echo -e "${CYAN} 8 Mysql change root password ${LIGHTGREEN} $MYSQL_CHANGE_ROOT_PASSWORD ${NC}"
    echo -e "${CYAN} 9 Mysql create database, user ${LIGHTGREEN} $MYSQL_CREATE ${NC}"
    echo -e "${CYAN} 10 Mysql remote access ${LIGHTGREEN} $MYSQL_CONFIG ${NC}"
    echo -e "${CYAN} 11 Install wireguard (under construction) ${NC}"
    echo -e "${CYAN} 12 Php.ini configuration cli + apache2 ${NC}"
    echo -e "${CYAN} 13 Exit ${NC}"
    echo "###################################################################################"
    read -p "Select an option: " key
    select_option $key
}

show_menu


