package Netdot::Model::RRNS;

use base 'Netdot::Model';
use warnings;
use strict;

my $logger = Netdot->log->get_logger('Netdot::Model::DNS');

=head1 Netdot::Model::RRNS - DNS NS record Class

=head1 SYNOPSIS


=head1 CLASS METHODS
=cut
############################################################################
=head2 insert - Insert new RRNS object

    We override the base method to:
    - Check if owner is an alias

  Arguments:
    See schema
  Returns:
    RRNS object
  Example:
    my $record = RRNS->insert(\%args)

=cut
sub insert {
    my($class, $argv) = @_;
    $class->isa_class_method('insert');

    $class->throw_fatal('Missing required arguments: rr')
	unless ( $argv->{rr} );

    $class->throw_user("Missing required argument: nsdname")
	unless $argv->{nsdname};

    my $rr = (ref $argv->{rr})? $argv->{rr} : RR->retrieve($argv->{rr});
    $class->throw_fatal("Invalid rr argument") unless $rr;

    my %linksfrom = RR->meta_data->get_links_from;
    foreach my $i ( keys %linksfrom ){
	next if ( $i eq 'ns_records' || $i eq 'ds_records' );
	if ( $rr->$i ){
	    $class->throw_user("NS records can only coexist with other NS or DS records for the same owner");
	}
    }

    return $class->SUPER::insert($argv);
    
}

=head1 INSTANCE METHODS
=cut
##################################################################
=head2 as_text

    Returns the text representation of this record

  Arguments:
    None
  Returns:
    string
  Examples:
    print $rr->as_text();

=cut
sub as_text {
    my $self = shift;
    $self->isa_object_method('as_text');

    return $self->_net_dns->string();
}


##################################################################
# Private methods
##################################################################


##################################################################
sub _net_dns {
    my $self = shift;

    # If TTL is not set, use Zone's default
    my $ttl = (defined $self->ttl && $self->ttl =~ /\d+/)? $self->ttl : $self->name->zone->default_ttl;

    my $ndo = Net::DNS::RR->new(
	name    => $self->rr->get_label,
	ttl     => $ttl,
	class   => 'IN',
	type    => 'NS',
	nsdname => $self->nsdname . '.',
	);
    
    return $ndo;
}

=head1 AUTHOR

Carlos Vicente, C<< <cvicente at ns.uoregon.edu> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 University of Oregon, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

#Be sure to return 1
1;

