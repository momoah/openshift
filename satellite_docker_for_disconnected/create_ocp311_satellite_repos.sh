#!/bin/bash
# Author: Mohammad Ahmad <mahmad@redhat.com>
# Version 1.0
# Version Control:
# - 1.0: Initial draft (Created 20191110)
# Description:
# This script needs to be run on the satellite server where you can run the hammer command. 
# It will create the docker images as satellite repositories within a product.
# For more information on how to perform disconnected installation of OpenShift with satellite, 
# see: https://developers.redhat.com/blog/2019/04/08/red-hat-openshift-3-11-disconnected-installation-using-satellite-docker-registry/


# Replace your tokenID and secret with the actual values below:

# From: https://access.redhat.com/terms-based-registry/#/token/
PATH=$PATH:/usr/local/sbin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/puppetlabs/bin:/root/bin

TOKENID="MyTokenID"
SECRET="MySecret"
MYORG="MyOrg"
MYPRODUCT="ocp311"
MYOCPIMAGEFILE="minimal_ocp311_images.txt"


RESPONSE=$(curl  -u $TOKENID:$SECRET --silent  --write-out %{http_code} --output /dev/null "https://sso.redhat.com/auth/realms/rhcc/protocol/redhat-docker-v2/auth?service=docker-registry&client_id=curl&scope=repository:rhel:pull")

if [ "$RESPONSE" == "200" ];

then

	cd /root

	TOTALREPOS=$(cat $MYOCPIMAGEFILE | wc -l);
	REPOCOUNT=0;

	hammer product info --name "$MYPRODUCT" --organization "$MYORG" > /dev/null 2>&1

	PRODUCTEXISTS=$?

	if [ "$PRODUCTEXISTS" != 0 ];
	then

	        hammer product create --name "$MYPRODUCT" --organization "$MYORG"
		echo "Created product $MYPRODUCT"
	else
		echo "Product $MYPRODUCT exists"
	fi

        for image in `cat $MYOCPIMAGEFILE`;
        do

		REPOCOUNT=$((REPOCOUNT+1))
                hammer repository info \
                --name $image \
                --product "$MYPRODUCT" \
                --organization "$MYORG"  > /dev/null 2>&1

                REPOEXISTS=$?

		if [ "$REPOEXISTS" != 0 ];
                then

                	hammer repository create \
			--name $image \
			--content-type docker \
			--url http://registry.redhat.io/ \
			--docker-upstream-name $image \
			--product "$MYPRODUCT" \
			--organization "$MYORG" \
			--upstream-username $TOKENID \
			--upstream-password $SECRET

			echo "Created $image repository ($REPOCOUNT/$TOTALREPOS)"

		else

                        hammer repository update \
                        --name $image \
                        --url http://registry.redhat.io/ \
                        --docker-upstream-name $image \
                        --product "$MYPRODUCT" \
                        --organization "$MYORG" \
                        --upstream-username $TOKENID \
                        --upstream-password $SECRET

			echo "Updated $image repository ($REPOCOUNT/$TOTALREPOS)"

                fi

        	hammer product synchronize --name "$MYPRODUCT" --organization "$MYORG"
		echo "Synchronised product $image"
        done

        hammer product synchronize --name "$MYPRODUCT" --organization "$MYORG" 
else
        echo "TOKENID/SECRET might be invalid, please check and try again"
fi

 
