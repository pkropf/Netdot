package Netdot::Model::RRCNAME;

use base 'Netdot::Model';
use warnings;
use strict;

my $logger = Netdot->log->get_logger('Netdot::Model::DNS');

=head1 Netdot::Model::RRCNAME - DNS CNAME record Class

=head1 SYNOPSIS


=head1 CLASS METHODS
=cut

############################################################################
=head2 insert - Insert new RRCNAME object

    We override the base method to:
    - Check if owner is an alias

  Arguments:
    See schema
  Returns:
    RRCNAME object
  Example:
    my $record = RRCNAME->insert(\%args)

=cut
sub insert {
    my($class, $argv) = @_;
    $class->isa_class_method('insert');

    $class->throw_fatal('Missing required arguments: name')
	unless ( $argv->{name} );

    $class->throw_user("Missing required argument: cname")
	unless $argv->{cname};

    my $rr = (ref $argv->{name})? $argv->{name} : RR->retrieve($argv->{name});
    $class->throw_fatal("Invalid name argument") unless $rr;

    my %linksfrom = RR->meta_data->get_links_from;
    foreach my $i ( keys %linksfrom ){
	if ( $rr->$i ){
	    $class->throw_user("Cannot add CNAME records when other records exist");
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


############################################################################
=head2 delete - Delete object
    
    We override the delete method for extra functionality:
    - When removing a RRCNAME object, the RR (name)
    associated with it needs to be deleted too.

  Arguments:
    None
  Returns:
    True if successful. 
  Example:
    $rrcname->delete;

=cut

sub delete {
    my $self = shift;
    $self->isa_object_method('delete');
    my $rr = $self->name;
    $self->SUPER::delete();
    $rr->delete();

    return 1;
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
	name    => $self->name->get_label,
	ttl     => $ttl,
	class   => 'IN',
	type    => 'CNAME',
	cname   => $self->cname,
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

