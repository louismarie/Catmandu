package Catmandu::App::Env;

use namespace::autoclean;
use Moose::Role;
use Catmandu::App::Request;

has env => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

has request => (
    is => 'ro',
    isa => 'Catmandu::App::Request',
    lazy => 1,
    builder => '_build_request',
);

sub _build_request {
    Catmandu::App::Request->new($_[0]->env);
}

sub req {
    $_[0]->request;
}

sub session {
    $_[0]->env->{'psgix.session'};
}

sub clear_session {
    my $session = $_[0]->session;
    for (keys %$session) {
        delete $session->{$_};
    }
    $session;
}

1;
