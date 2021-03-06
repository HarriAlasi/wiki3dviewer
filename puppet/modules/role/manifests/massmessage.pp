# == Class: role::massmessage
# This role provisions the MassMessage extension, which allows users to
# easily send a message to a list of pages via the job queue, and a set
# of extensions which integrate with it: LiquidThreads and Echo.
class role::massmessage {
    include ::role::echo

    mediawiki::extension { 'MassMessage': }

    mediawiki::extension { 'LiquidThreads':
        needs_update => true,
        settings     => {
            wgLqtTalkPages => false,
        },
    }
}
