package Catmandu::Cmd::delete;

use Catmandu::Sane;

our $VERSION = '0.9504';

use parent 'Catmandu::Cmd';
use Catmandu;
use Catmandu::Fix;
use namespace::clean;

sub command_opt_spec {
    (
        [ "query|q=s", "" ],
    );
}

sub command {
    my ($self, $opts, $args) = @_;

    my $from_args = [];
    my $from_opts = {};

    for (my $i = 0; $i < @$args; $i++) {
        my $arg = $args->[$i];
        if ($arg =~ s/^-+//) {
            $arg =~ s/-/_/g;
            $from_opts->{$arg} = $args->[++$i];
        } else {
            push @$from_args, $arg;
        }
    }

    my $from_bag = delete $from_opts->{bag};
    my $from = Catmandu->store($from_args->[0], $from_opts)->bag($from_bag);
    if (defined $opts->query) {
        $from->delete_by_query(query => $opts->query);
    } else {
        $from->delete_all;
    }

    $from->commit;

    unless ($from->count == 0) {
        say STDERR "error: $from is not empty";
    }
}

1;

__END__

=pod

=head1 NAME

Catmandu::Cmd::delete - delete objects from a store

=head1 EXAMPLES

  catmandu delete <STORE> <OPTIONS>

  catmandu delete ElasticSearch --index-name items --bag book \
                                --query 'title:"My Rabbit"'

  catmandu help store ElasticSearch
  
=cut
