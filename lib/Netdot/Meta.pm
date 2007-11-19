package Netdot::Meta;

use Netdot::Meta::Table;

use strict;
use Carp;


# Default location of the file that contains Meta Information
my $META_FILE = "<<Make:ETC>>/netdot.meta";

# Some private class data and related methods
{
    # Cache Meta::Table objects
    my %_table_cache;

    sub _cache_table {
	my ($self, $obj) = @_;
	$_table_cache{$obj->name} = $obj;
	return 1;
    }
    sub _get_cached_table{
	my ($self, $name) = @_;
	if ( exists $_table_cache{$name} ){
	    return $_table_cache{$name} ;
	}
    }
}

#Be sure to return 1
1;

=head1 NAME

Netdot::Meta - Metainformation Class for Netdot

=head1 SYNOPSIS


=head1 PUBLIC METHODS

=head2 new - Class Constructor
    
    my $metainfo = Netdot::Meta->new(meta_file => "path/to/meta_file");
    
=cut
sub new {
    my ($proto, %argv) = @_;
    my $class = ref($proto) || $proto;
    my $file = $argv{'meta_file'} || $META_FILE;
    my $self = do "$file" or croak "Netdot::Meta::new(): Can't read $file: $@ || $!";
    unless (ref($self) eq "HASH"){
	croak "Netdot::Meta::new(): Error in metadata: file is not a valid hash reference: $file";
    }
    bless $self, $class;
}

##################################################
=head2 get_table_names -  Returns an array of table names
    
  Arguments:
    None
  Returns:
    Array containing table names
  Example: 

    @tables = $meta->get_table_names();

=cut
sub get_table_names{
    my $self = shift;
    my @names = sort keys %{$self->_get_tables_hash()};
    return @names;
}

##################################################
=head2 get_table -  Get new Table object
    
  Arguments:
    Table name
  Returns:
    New Table object 
  Example: 
    my $mdevice = $meta->get_table('Device');
    
=cut
sub get_table{
    my ($self, $name) = @_;
    my $newtable;
    if ( $newtable = $self->_get_cached_table($name) ){
	return $newtable;
    }else{
	my $actual_name = $name;
	my $hf = $self->get_history_suffix();
	$actual_name =~ s/$hf//;
	my $info = $self->_get_table_info($actual_name);
	$info->{name} = $name;
	$info->{meta} = $self;
	# Let new table know if it is a history table
	if ( $name ne $actual_name ){
	    $info->{is_history}     = 1;
	    $info->{original_table} = $actual_name;
	    $info->{has_history}    = 0;
	}else{
	    $info->{is_history}     = 0;
	}
	$newtable = Netdot::Meta::Table->new($info);
	$self->_cache_table($newtable);
    }
    return $newtable;
}

##################################################
=head2 get_tables - Get a list of all Table objects

  Arguments:
    with_history - If true, history tables will be included in the array
  Returns:
    Array
  Example: 
    my @meta_tables = $meta->get_tables;

=cut
sub get_tables {
    my ($self, %argv) = @_;
    my @tables;
    push @tables, $self->get_table($_) foreach $self->get_table_names();
    my @all_tables = @tables;
    # Add history tables if told to
    if ( $argv{with_history} ){
	foreach my $mtable ( @tables ){
	    if ( !$mtable->is_history
		 && ( my $hname = $mtable->get_history_table_name() ) ){
		push @all_tables, $self->get_table($hname);
	    }
	}
    }
    return @all_tables;
}

##################################################
=head2 cdbi_class - Produce Class::DBI subclass
    
  Arguments:
    table     - Meta::Table object
    base      - Our main Class::DBI subclass (base for other subclasses)
    namespace - Classes will be defined under this namespace
  Returns:
    Array containing: Package name, Class definition
  Example: 
    my $subclass = $meta->cdbi_class(table => $table, base => "Some::Package");

=cut
sub cdbi_class{
    my ($self, %argv) = @_;
    my %classes;
    croak "cdbi_classes: Need to pass Meta::Table object" unless $argv{table};
    croak "cdbi_classes: Need to pass base class" unless $argv{base};

    # Build a Class for each DB table
    my $table = $argv{table};
    my ($code, $package);
    $package = ($argv{namespace}) ? $argv{namespace}."::".$table->name : $table->name;
    $code .= "package ".$package.";\n";
    $code .= "use base '$argv{base}';\n";
    my $tname = $table->name;
    $tname = lc($tname);
    $code .= "__PACKAGE__->table( '$tname' );\n";
	
    # Set up primary columns
    $code .=  "__PACKAGE__->columns( Primary => qw / id /);\n";
    
    # Define 'Essential' and 'Others' 
    my %cols;
    map { $cols{$_->name} = '' } $table->get_columns;
    delete $cols{'id'};
    my %brief = $table->get_column_order_brief();
    my @essential = keys %brief;
    my $essential = join ' ', @essential;
    $code .= "__PACKAGE__->columns( Essential => qw / $essential /);\n" if (@essential);
    delete $cols{$_} foreach (@essential);
    my $others = join ' ', keys %cols;
    $code .= "__PACKAGE__->columns( Others => qw / $others /);\n" if (keys %cols);
    
    # Set up has_a relationships
    foreach my $c ( $table->get_columns() ){
	if ( my $ft = $c->links_to() ){
	    $ft = ($argv{namespace}) ? $argv{namespace}."::".$ft : $ft;
	    $code .= "__PACKAGE__->has_a( ".$c->name." => '$ft' );\n";
	}
    }
    
    # Set up has_many relationships
    my %hm = $table->get_links_from();
    foreach my $rel ( keys %hm ){
	my $method = $rel;
	my $tab;
	# A has_many relationship should not point to a history table unless
	# it is the 'history_records' method.
	foreach my $key ( keys %{$hm{$rel}} ){
	    my $hf = $self->get_history_suffix;
	    next if $key =~ /$hf$/ && $method !~ /history_records/;
	    $tab = $key;
	}
	croak "cdbi_classes: Can't get has_many table from ", $table->name, ":$method" unless $tab;
	my $col    = $hm{$rel}{$tab};
	my $t      = $self->get_table($tab);
	my $c      = $t->get_column($col);
	my $l      = $c->links_to_attrs();
	my $casc   = $l->{cascade};
	croak "cdbi_classes: Missing 'cascade' entry for $tab:$col" unless $casc;
	my $arg;
	if ( $casc eq 'Nullify' ){
	    $arg = "{cascade=>'Class::DBI::Cascade::Nullify'}";
	}elsif ( $casc =~ /^Delete|Fail$/i ){
	    $arg = "{cascade=>'$casc'}";
	}else{
	    croak "cdbi_classes: Unknown cascade behavior $casc";
	}
	$tab = ($argv{namespace}) ? $argv{namespace}."::".$tab : $tab;
	$code .= "__PACKAGE__->has_many( '$method', '$tab' => '$col', $arg );\n";
    }

    return ($package, $code);
}


##################################################
=head2 get_history_suffix - Get suffix used to name history tables;
    
  Arguments:
    None
  Returns:
    string
  Example: 

=cut
sub get_history_suffix{
    my $self = shift;
    my $HIST = '_history';
    return $HIST;
}


##################################################################
#
# Private Methods
#
##################################################################

##################################################
# _get_tables_hash
#
# Returns an hashref of table hashrefs containing metadata
#

sub _get_tables_hash{
    my $self = shift;
    croak "_get_tables_hash: Error getting table info"
	if (! exists $self->{tables});
    my %ret = %{ $self->{tables} };
    return \%ret;
}

##################################################
# _get_table_info
#
# Returns an hashref containing table metadata
#

sub _get_table_info{
    my ($self, $name) = @_;
    croak "_get_table_info: Need to pass table name"
	unless $name;
    my $tables = $self->_get_tables_hash();
    croak "_get_table_info: Table $name does not exist" 
	unless exists $tables->{$name};
    # We need to make a copy of the hash.  Otherwise
    # unexpected things will happen.
    my %info = %{ $tables->{$name} };
    return \%info;
}
