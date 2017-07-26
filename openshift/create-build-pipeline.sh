#!/usr/bin/env bash
cd $(dirname $(realpath $0))
FOLDER=$(pwd)

echo "ARGS: $@"
STAGE=$1

if [[ $1 =~ delete ]]; then
    OS_DELETE_ONLY=true
    STAGE=$2
fi
if [[ $1 =~ build ]]; then
    OS_BUILD_ONLY=true
    STAGE=$2
fi
if [[ $STAGE == "" ]]; then
    echo "define var 'STAGE'!"
    exit -1
fi
echo "ENVS: STAGE=$STAGE"

TEMPLATE=$FOLDER/build.pipeline.yml
count=0


function createOpenshiftObject(){
    app_name=$1
    echo "CREATE Config for $app_name"
    oc process -f "$TEMPLATE" \
        -v APP_NAME=$app_name \
        -v STAGE=$STAGE \
        | oc apply -f -
    oc get all -l application=$app_name
}

function deleteOpenshiftObject(){
    app_name=$1
    echo "DELETE Config for $app_name"
        oc process -f "$TEMPLATE" \
        -v APP_NAME=$app_name \
        -v STAGE=$STAGE \
        | oc delete -f -
    echo ".... wait" && sleep 3
    oc delete pod -l jenkins=slave
}

function buildOpenshiftObject(){
    app_name=$1
    echo "Trigger Build for $app_name"
    oc start-build $app_name --follow --wait
    oc get builds -l application=$app_name
}


function deployToOpenshift() {
    app_name=$1
    echo "--------------------- CREATE $app_name ---------------------------------------"
    if [[ $OS_BUILD_ONLY == "true" ]]; then
        buildOpenshiftObject $app_name
    elif [[ $OS_DELETE_ONLY == "true" ]]; then
        deleteOpenshiftObject $app_name
    else
        createOpenshiftObject $app_name
        echo "...." && sleep 3
        buildOpenshiftObject $app_name
    fi
    echo "-------------------------------------------------------------------"
    ((count++))

}

oc project oshift-day-dev
deployToOpenshift "bakery-$STAGE-ci"

wait
exit $?
