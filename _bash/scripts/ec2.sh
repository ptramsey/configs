ec2() {
    instance_name="$1"
    shift
    query='Reservations[0].Instances[0].[InstanceId,State.Name,PublicDnsName]'

    while true; do
        exec {ec2}< <(aws ec2 describe-instances --filters Name=tag:Name,Values="$instance_name" \
                                                 --output text \
                                                 --query "$query")
        read instance_id state hostname <&$ec2
        exec {ec2}<&-

        case $state in
        running)
            printf '%100s\r'
            ssh fivestars@$hostname "$@"
            break
            ;;
        stopped|stopping)
            aws ec2 start-instances --instance-ids $instance_id >/dev/null
            echo -n "Starting $instance_name..."
            ;&
        pending)
            sleep 5
            echo -n "."
            ;;
        *)
            echo "Instance is in state $state; giving up"
            return 1
            ;;
        esac
    done
}
