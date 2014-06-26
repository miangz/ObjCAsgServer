//
//  ldapTest.m
//  Server
//
//  Created by miang on 5/2/2557 BE.
//
//

#import "ldapTest.h"

#include <stdio.h>
#include "ldap.h"
#define HOSTNAME "localhost"
#define PORTNUMBER LDAP_PORT
//#define BIND_DN "cn=Directory Manager"
#define BIND_PW "asdf1234"
#define USER_DN "cn=admin,dc=localhost,dc=com"
#define NUM_MODS 6

@implementation ldapTest

void do_other_work();

int global_counter = 0;

void free_mods( LDAPMod **mods );

LDAP *
ldap_init( LDAP_CONST char *defhost, int defport );

int
ldap_simple_bind_s( LDAP *ld, LDAP_CONST char *dn, LDAP_CONST char *passwd );


char **
ldap_get_values( LDAP *ld, LDAPMessage *entry, LDAP_CONST char *target );


void
ldap_value_free( char **vals );

int
ldap_unbind( LDAP *ld );

int
ldap_unbind_s( LDAP *ld );
/*
 
 * Free a mods array.
 
 */

void

free_mods( LDAPMod **mods )

{
    
    int i;
    
    for ( i = 0; i < NUM_MODS; i++ ) {
        
        free( mods[ i ] );
        
    }
    
    free( mods );
    
}

/*
 
 * Perform other work while polling for results. This doesn't do anything
 
 * useful, but it could.
 
 */

void do_other_work()

{
    
    global_counter++;
    
}

-(char *)retrieveEntry:(char *)uid{
    char dn[100];
    strcpy(dn,"cn=");
    strcat(dn, uid);
    strcat(dn, ",dc=localhost,dc=com");
    
    LDAP *ld;
    
    LDAPMessage *result, *e;
    
    BerElement *ber;
    
    char *a;
    
    char **vals;
    
    int i, rc;
    
    /* Get a handle to an LDAP connection. */
    
    if ( (ld = ldap_init( HOSTNAME, PORTNUMBER )) == NULL ) {
        
        NSLog(@"port no. : %d",PORTNUMBER);
        perror( "ldap_init" );
        
        return "0";
        
    }
    
    /* set version */
    int version = LDAP_VERSION3;
    ldap_set_option( ld, LDAP_OPT_PROTOCOL_VERSION, &version );
    
    if (ldap_set_option(ld, LDAP_OPT_PROTOCOL_VERSION, &version)
        != LDAP_SUCCESS)
    {
        printf("ldap_set_option error\n");
        return "0";
    }
    
    /* Bind anonymously to the LDAP server. */
    
    rc = ldap_simple_bind_s( ld, USER_DN , BIND_PW );
    NSLog(@"A0");
    
    if ( rc != LDAP_SUCCESS ) {
        
        fprintf(stderr, "ldap_simple_bind_s: %s\n", ldap_err2string(rc));
        return "0";
        
    }
    NSLog(@"A1");
    
    /* Search for the entry. */
    
    if ( ( rc = ldap_search_ext_s( ld, dn, LDAP_SCOPE_BASE,
                                  
                                  "(objectclass=*)", NULL, 0, NULL, NULL, LDAP_NO_LIMIT,
                                  
                                  LDAP_NO_LIMIT, &result ) ) != LDAP_SUCCESS ) {
        
        fprintf(stderr, "ldap_search_ext_s: %s\n", ldap_err2string(rc));
        
        return "0";
    }
    
    
    e = ldap_first_entry( ld, result );
    NSLog(@"A2");
    if ( e != NULL ) {
        
        printf( "\nFound %s:\n\n", dn );
        
        /* Iterate through each attribute in the entry. */
        
        for ( a = ldap_first_attribute( ld, e, &ber );
             
             a != NULL; a = ldap_next_attribute( ld, e, ber ) ) {
            
            /* For each attribute, print the attribute name and values. */
            
            if ((vals = ldap_get_values( ld, e, a)) != NULL ) {
                
                for ( i = 0; vals[i] != NULL; i++ ) {
                    
                    printf( "%s[%d]: %s \n", a,i, vals[i] );
                    NSString *result = [NSString stringWithCString:a encoding:NSUTF8StringEncoding];
                    if ([result isEqualToString:@"userPassword"]) {
                        return vals[i];
                    }
                }
                
                ldap_value_free( vals );
                
            }
            
            ldap_memfree( a );
            
        }
        
        if ( ber != NULL ) {
            
            ber_free( ber, 0 );
            
        }
        
        ldap_msgfree( result );
        
        ldap_unbind( ld );
        
        NSLog(@"A3");
        return "0";
        
    }
    
    ldap_msgfree( result );
    
    ldap_unbind( ld );
    
    NSLog(@"A3");
    return "0";
}

-(char *)getStockList:(char *)uid{
    char dn[100];
    strcpy(dn,"cn=");
    strcat(dn, uid);
    strcat(dn, ",dc=localhost,dc=com");
    
    LDAP *ld;
    
    LDAPMessage *result, *e;
    
    BerElement *ber;
    
    char *a;
    
    char **vals;
    
    int i, rc;
    
    /* Get a handle to an LDAP connection. */
    
    if ( (ld = ldap_init( HOSTNAME, PORTNUMBER )) == NULL ) {
        
        NSLog(@"port no. : %d",PORTNUMBER);
        perror( "ldap_init" );
        
        return "0";
        
    }
    
    /* set version */
    int version = LDAP_VERSION3;
    ldap_set_option( ld, LDAP_OPT_PROTOCOL_VERSION, &version );
    
    if (ldap_set_option(ld, LDAP_OPT_PROTOCOL_VERSION, &version)
        != LDAP_SUCCESS)
    {
        printf("ldap_set_option error\n");
        return "0";
    }
    
    /* Bind anonymously to the LDAP server. */
    
    rc = ldap_simple_bind_s( ld, USER_DN , BIND_PW );
    NSLog(@"A0");
    
    if ( rc != LDAP_SUCCESS ) {
        
        fprintf(stderr, "ldap_simple_bind_s: %s\n", ldap_err2string(rc));
        return "0";
        
    }
    NSLog(@"A1");
    
    /* Search for the entry. */
    
    if ( ( rc = ldap_search_ext_s( ld, dn, LDAP_SCOPE_BASE,
                                  
                                  "(objectclass=*)", NULL, 0, NULL, NULL, LDAP_NO_LIMIT,
                                  
                                  LDAP_NO_LIMIT, &result ) ) != LDAP_SUCCESS ) {
        
        fprintf(stderr, "ldap_search_ext_s: %s\n", ldap_err2string(rc));
        
        return "0";
    }
    
    
    e = ldap_first_entry( ld, result );
    NSLog(@"A2");
    if ( e != NULL ) {
        
        printf( "\nFound %s:\n\n", dn );
        
        /* Iterate through each attribute in the entry. */
        
        for ( a = ldap_first_attribute( ld, e, &ber );
             
             a != NULL; a = ldap_next_attribute( ld, e, ber ) ) {
            
            /* For each attribute, print the attribute name and values. */
            
            if ((vals = ldap_get_values( ld, e, a)) != NULL ) {
                
                for ( i = 0; vals[i] != NULL; i++ ) {
                    
                    printf( "%s[%d]: %s \n", a,i, vals[i] );
                    NSString *result = [NSString stringWithCString:a encoding:NSUTF8StringEncoding];
                    if ([result isEqualToString:@"description"]) {
                        return vals[i];
                    }
                }
                
                ldap_value_free( vals );
                
            }
            
            ldap_memfree( a );
            
        }
        
        if ( ber != NULL ) {
            
            ber_free( ber, 0 );
            
        }
        
        ldap_msgfree( result );
        
        ldap_unbind( ld );
        
        NSLog(@"A3");
        return "0";
        
    }
    
    ldap_msgfree( result );
    
    ldap_unbind( ld );
    
    NSLog(@"A3");
    return "0";
}



-(int)addASyncWithCN:(char*)cname SN:(char*)sname uid:(char*)uid andPass:(char*)pass{
    
    if (cname == nil || sname == nil || pass == nil) {
        printf("\n sth is nil!!!!!");
        return 0;
    }
    
    LDAP *ld;
    
    LDAPMessage *res;
    
    LDAPMod **mods;
    
    LDAPControl **serverctrls;
    
    char *matched_msg = NULL, *error_msg = NULL;
    
    char **referrals;
    
    int i, rc, parse_rc, msgid, finished = 0;
    
    struct timeval zerotime;
    
    char *object_vals[] = { "top", "person", "organizationalPerson", "inetOrgPerson", NULL };
    
    char *cn_vals[] = { cname, NULL };
    
    char *sn_vals[] = {sname, NULL };
    
    char *uid_vals[] = {uid, NULL };
    
    char *userPassword[] = { pass, NULL };
    
    char *des_vals[] = {"default",NULL};
    
    zerotime.tv_sec = zerotime.tv_usec = 0L;
    
    /* Get a handle to an LDAP connection. */
    
    if ( (ld = ldap_init( HOSTNAME, PORTNUMBER )) == NULL ) {
        
        perror( "ldap_init" );
        
        return( 1 );
        
    }
    NSLog(@"1");
    
    /* set version */
    int version = LDAP_VERSION3;
    ldap_set_option( ld, LDAP_OPT_PROTOCOL_VERSION, &version );
    
    if (ldap_set_option(ld, LDAP_OPT_PROTOCOL_VERSION, &version)
        != LDAP_SUCCESS)
    {
        printf("ldap_set_option error\n");
        return 1;
    }
    
    NSLog(@"2");
    /* Bind to the server as the Directory Manager. */
    
    rc = ldap_simple_bind_s( ld, USER_DN, BIND_PW );
    
    NSLog(@"3");
    if ( rc != LDAP_SUCCESS ) {
        
        fprintf( stderr, "ldap_simple_bind_s: %s\n", ldap_err2string( rc ) );
        
        //ldap_get_lderrno( ld, &matched_msg, &error_msg );
        
        if ( error_msg != NULL && *error_msg != '\0' ) {
            
            fprintf( stderr, "%s\n", error_msg );
            
        }
        
        if ( matched_msg != NULL && *matched_msg != '\0' ) {
            
            fprintf( stderr,
                    
                    "Part of the DN that matches an existing entry: %s\n",
                    
                    matched_msg );
            
        }
        
        ldap_unbind_s( ld );
        
        return( 1 );
        
    }
    
    NSLog(@"4");
    /* Construct the array of LDAPMod structures representing the attributes
     
     of the new entry. */
    
    mods = ( LDAPMod ** ) malloc(( NUM_MODS + 1 ) * sizeof( LDAPMod * ));
    
    if ( mods == NULL ) {
        
        fprintf( stderr, "Cannot allocate memory for mods array\n" );
        
        exit( 1 );
        
    }
    
    for ( i = 0; i < NUM_MODS; i++ ) {
        
        if (( mods[ i ] = ( LDAPMod * ) malloc( sizeof( LDAPMod ))) == NULL ) {
            
            fprintf( stderr, "Cannot allocate memory for mods element\n" );
            
            exit( 1 );
            
        }
        
    }
    
    mods[ 0 ]->mod_op = 0;
    
    mods[ 0 ]->mod_type = "objectclass";
    
    mods[ 0 ]->mod_values = object_vals;
    
    mods[ 1 ]->mod_op = 0;
    
    mods[ 1 ]->mod_type = "cn";
    
    mods[ 1 ]->mod_values = cn_vals;
    
    mods[ 2 ]->mod_op = 0;
    
    mods[ 2 ]->mod_type = "sn";
    
    mods[ 2 ]->mod_values = sn_vals;
    
    mods[ 3 ]->mod_op = 0;
    
    mods[ 3 ]->mod_type = "uid";
    
    mods[ 3 ]->mod_values = uid_vals;
    
    mods[ 4 ]->mod_op = 0;
    
    mods[ 4 ]->mod_type = "userPassword";
    
    mods[ 4 ]->mod_values = userPassword;
    
    mods[ 5 ]->mod_op = 0;
    
    mods[ 5 ]->mod_type = "description";
    
    mods[ 5 ]->mod_values = des_vals;
    
    mods[ 6 ] = NULL;
    
    /* Send the LDAP add request. */
    char dn[100];
    strcpy(dn,"cn=");
    strcat(dn, uid);
    strcat(dn, ",dc=localhost,dc=com");
    
    rc = ldap_add_ext( ld, dn, mods, NULL, NULL, &msgid );
    
    if ( rc != LDAP_SUCCESS ) {
        
        fprintf( stderr, "ldap_add_ext: %s\n", ldap_err2string( rc ) );
        
        ldap_unbind( ld );
        
        free_mods( mods );
        
        return( 1 );
        
    }
    
    /* Poll the server for the results of the add operation. */
    
    while ( !finished ) {
        
        rc = ldap_result( ld, msgid, 0, &zerotime, &res );
        
        switch ( rc ) {
                
            case -1:
                
                /* An error occurred. */
                
               // rc = ldap_get_lderrno( ld, NULL, NULL );
                
                fprintf( stderr, "ldap_result: %s\n", ldap_err2string( rc ) );
                
                ldap_unbind( ld );
                
                free_mods( mods );
                
                return( 1 );
                
            case 0:
                
                /* The timeout period specified by zerotime was exceeded.
                 
                 This means that the server has still not yet sent the
                 
                 results of the add operation back to your client.
                 
                 Break out of this switch statement, and continue calling
                 
                 ldap_result() to poll for results. */
                
                break;
                
            default:
                
                /* The function has retrieved the results of the add operation
                 
                 from the server. */
                
                finished = 1;
                
                /* Parse the results received from the server. Note the last
                 
                 argument is a non-zero value, which indicates that the
                 
                 LDAPMessage structure will be freed when done. (No need
                 
                 to call ldap_msgfree().) */
                
                parse_rc = ldap_parse_result( ld, res, &rc, &matched_msg, &error_msg, &referrals, &serverctrls, 1 );
                
                if ( parse_rc != LDAP_SUCCESS ) {
                    
                    fprintf( stderr, "ldap_parse_result: %s\n", ldap_err2string( parse_rc ) );
                    
                    ldap_unbind( ld );
                    
                    free_mods( mods );
                    
                    return( 1 );
                    
                }
                
                /* Check the results of the LDAP add operation. */
                
                if ( rc != LDAP_SUCCESS ) {
                    
                    fprintf( stderr, "ldap_add_ext: %s\n", ldap_err2string( rc ) );
                    
                    if ( error_msg != NULL & *error_msg != '\0' ) {
                        
                        fprintf( stderr, "%s\n", error_msg );
                        
                    }
                    
                    if ( matched_msg != NULL && *matched_msg != '\0' ) {
                        
                        fprintf( stderr,"Part of the DN that matches an existing entry: %s\n",matched_msg );
                        
                    }
                    
                } else {
                    
                    printf( "%s added successfully.\nCounted to %d while waiting for the add operation.\n",USER_DN, global_counter );
                    
                    ldap_unbind( ld );
                    
                    free_mods( mods );
                    
                    return 111;
                }
                
        }
        
        /* Do other work while waiting for the results of the add operation. */
        
        if ( !finished ) {
            
            do_other_work();
            
        }
        
    }
    
    ldap_unbind( ld );
    
    free_mods( mods );
    
    return 0;
}

-(int) modify:(char *)stock withUID:(char *)uid{
    
    LDAP *ld;
    
    LDAPMessage *res;
    
    LDAPMod **mods;
    
    char **referrals;
    
    LDAPControl **serverctrls;
//    LDAPMod attribute1;
    
    
    char *matched_msg = NULL, *error_msg = NULL;
    
    int i, rc, parse_rc, msgid, finished = 0;
    
    struct timeval zerotime;
    
    char *des_vals[] = {stock,NULL};
    
    zerotime.tv_sec = zerotime.tv_usec = 0L;
    
    /* Get a handle to an LDAP connection. */
    
    if ( (ld = ldap_init( HOSTNAME, PORTNUMBER )) == NULL ) {
        
        perror( "ldap_init" );
        
        return( 1 );
        
    }
    NSLog(@"1");
    
    /* set version */
    int version = LDAP_VERSION3;
    ldap_set_option( ld, LDAP_OPT_PROTOCOL_VERSION, &version );
    
    if (ldap_set_option(ld, LDAP_OPT_PROTOCOL_VERSION, &version)
        != LDAP_SUCCESS)
    {
        printf("ldap_set_option error\n");
        return 1;
    }
    
    NSLog(@"2");
    /* Bind to the server as the Directory Manager. */
        rc = ldap_simple_bind_s( ld, USER_DN, BIND_PW );
    
    NSLog(@"3");
    if ( rc != LDAP_SUCCESS ) {
        
        fprintf( stderr, "ldap_simple_bind_s: %s\n", ldap_err2string( rc ) );
        
        //ldap_get_lderrno( ld, &matched_msg, &error_msg );
        
        if ( error_msg != NULL && *error_msg != '\0' ) {
            
            fprintf( stderr, "%s\n", error_msg );
            
        }
        
        if ( matched_msg != NULL && *matched_msg != '\0' ) {
            
            fprintf( stderr,
                    
                    "Part of the DN that matches an existing entry: %s\n",
                    
                    matched_msg );
            
        }
        
        ldap_unbind_s( ld );
        
        return( 1 );
        
    }
    
    NSLog(@"4");
    
    mods = ( LDAPMod ** ) malloc(( 2 ) * sizeof( LDAPMod * ));
    
    if ( mods == NULL ) {
        
        fprintf( stderr, "Cannot allocate memory for mods array\n" );
        
        exit( 1 );
        
    }
    for ( i = 0; i < 1; i++ ) {
        
        if (( mods[ i ] = ( LDAPMod * ) malloc( sizeof( LDAPMod ))) == NULL ) {
            
            fprintf( stderr, "Cannot allocate memory for mods element\n" );
            
            exit( 1 );
            
        }
        
    }
    
    mods[ 0 ]->mod_op = LDAP_MOD_REPLACE;
    
    mods[ 0 ]->mod_type = "description";
    
    mods[ 0 ]->mod_values = des_vals;
    
    mods[ 1 ] = NULL;
    
    
    /* Send the LDAP add request. */
    char dn[100];
    strcpy(dn,"cn=");
    strcat(dn, uid);
    strcat(dn, ",dc=localhost,dc=com");
    
    
    rc = ldap_modify_ext( ld, dn, mods, NULL, NULL, &msgid );
    
    if ( rc != LDAP_SUCCESS ) {
        
        fprintf( stderr, "ldap_modify_ext: %s\n", ldap_err2string( rc ) );
        
        ldap_unbind( ld );
        
        free_mods( mods );
        
        return( 1 );
        
    }
    
    /* Poll the server for the results of the add operation. */
    
    while ( !finished ) {
        
        rc = ldap_result( ld, msgid, 0, &zerotime, &res );
        
        switch ( rc ) {
                
            case -1:
                
                /* An error occurred. */
                
                // rc = ldap_get_lderrno( ld, NULL, NULL );
                
                fprintf( stderr, "ldap_result: %s\n", ldap_err2string( rc ) );
                
                ldap_unbind( ld );
                
                free_mods( mods );
                
                return( 1 );
                
            case 0:
                
                /* The timeout period specified by zerotime was exceeded.
                 
                 This means that the server has still not yet sent the
                 
                 results of the add operation back to your client.
                 
                 Break out of this switch statement, and continue calling
                 
                 ldap_result() to poll for results. */
                
                break;
                
            default:
                
                /* The function has retrieved the results of the add operation
                 
                 from the server. */
                
                finished = 1;
                
                /* Parse the results received from the server. Note the last
                 
                 argument is a non-zero value, which indicates that the
                 
                 LDAPMessage structure will be freed when done. (No need
                 
                 to call ldap_msgfree().) */
                
                parse_rc = ldap_parse_result( ld, res, &rc, &matched_msg, &error_msg, &referrals, &serverctrls, 1 );
                
                if ( parse_rc != LDAP_SUCCESS ) {
                    
                    fprintf( stderr, "ldap_parse_result: %s\n", ldap_err2string( parse_rc ) );
                    
                    ldap_unbind( ld );
                    
                    free_mods( mods );
                    
                    return( 1 );
                    
                }
                
                /* Check the results of the LDAP add operation. */
                
                if ( rc != LDAP_SUCCESS ) {
                    
                    fprintf( stderr, "ldap_modify_ext: %s\n", ldap_err2string( rc ) );
                    
                    if ( error_msg != NULL & *error_msg != '\0' ) {
                        
                        fprintf( stderr, "%s\n", error_msg );
                        
                    }
                    
                    if ( matched_msg != NULL && *matched_msg != '\0' ) {
                        
                        fprintf( stderr,"Part of the DN that matches an existing entry: %s\n",matched_msg );
                        
                    }
                    
                } else {
                    
                    printf( "%s modified successfully.\nCounted to %d while waiting for the modify operation.\n",USER_DN, global_counter );
                    
                    ldap_unbind( ld );
                    
                    free( mods );
                    
                    return 111;
                }
                
        }
        
        /* Do other work while waiting for the results of the add operation. */
        
        if ( !finished ) {
            
            do_other_work();
            
        }
        
    }
    
    ldap_unbind( ld );
    
    free( mods );

    
    return 0;
    
    
}

-(BOOL)isLenghtValid:(char*)c{
    if (strlen(c)>20) {
        return NO;
    }
    return YES;
}
@end
