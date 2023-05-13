#!/bin/bash
#set -exu


##################################################
# 修改这里的4个字段即可
# 从官网获取api token以及网络id
apitoken="XXXXXXXXXXXXXXXXX"
networkid="XXXXXXXXXXX"

# 填写预加入设备的名称和描述
clientname="test-cloud"
clientdescription="测试"
###################################################


# 检测并安装zerotier-one, curl, jq
function checkandinstall() {
    whereis curl > /dev/null 2>&1 || whereis jq > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "请先安装curl和jq" && exit 1
    fi
    systemctl status zerotier-one >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "接下来，将使用官网脚本安装zerotier-one" && sleep 2
        curl -s https://install.zerotier.com | sudo bash
        if [[ $? -eq 0 ]]; then
            echo "Zerotier-one安装成功" && return 0
        fi
    fi

}

checkandinstall

echo "申请加入网络" && /usr/sbin/zerotier-cli join $networkid > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    # 设置访问的api token
    headers="Authorization: token $apitoken"
    # 获取本机客户端id
    clientid=$(/usr/sbin/zerotier-cli info | awk '{print $3}')
    # 确认客户端id是否已认证
    authorized=$(curl -s -X GET -H "$headers" https://my.zerotier.com/api/network/$networkid/member/$clientid | jq -r ".config.authorized")

    # 如果该设备还没有经过验证，则发送验证请求
    if [[ $authorized == false ]]; then
        authorize_url="https://my.zerotier.com/api/network/$networkid/member/$clientid"
        data='{"config": {"authorized": true}, "name": "'$clientname'" , "description": "'$clientdescription'"}'
        # 对客户端进行认证
        echo "网络认证中" && curl -s -X POST -H "$headers" --data "$data" $authorize_url >/dev/null 2>&1 && echo "网络认证成功"
        # 确认客户端id是否已认证
        authorized=$(curl -s -X GET -H "$headers" https://my.zerotier.com/api/network/$networkid/member/$clientid | jq -r ".config.authorized")
        if [[ $authorized == true ]]; then
                echo "客户端已认证成功,Zerotier-one子网中所有设备信息如下"
                # 获取所有客户端信息
                curl -s -X GET -H "$headers" https://my.zerotier.com/api/network/$networkid/member | jq -r '.[] | [.nodeId, .online, .config.ipAssignments[],.name, .description] | join("\t\t")' | awk 'BEGIN{printf "%-15s\t%-15s\t%-20s%-15s%-15s\n","nodeid","online","ip","name","description"}{printf "%-15s\t%-15s\t%-20s%-15s%-15s\n", $1,$2,$3,$4,$5}'
        fi
    fi
fi


