program state_dummy

      use kinds_mod
      use constants
      use omp_lib

      implicit none

      integer (int_kind), parameter :: &
      nx_block = 2880, &
      ny_block = 2619, &
      km = 60

      real (r8), dimension(nx_block,ny_block) :: TMIX,TEMP1,TEMP2,TEMP3
 
      real (r8), dimension(nx_block,ny_block) :: DRDT,DRDS

      integer (int_kind) kk, this_block

      this_block = 1
      kk = 1

      call random_number(TMIX)  
      call random_number(TEMP1)
      call random_number(TEMP2)
      call random_number(TEMP3)

      call state (kk, kk, TMIX, TMIX, this_block, RHOOUT=DRDT,RHOFULL=DRDS,DRHODT=TEMP1,DRHODS=TEMP2)  
      

contains

subroutine state(k, kk, TEMPK, SALTK, this_block, RHOOUT, RHOFULL, DRHODT, DRHODS)




      integer (int_kind), intent(in) :: this_block 

      !integer (int_kind), parameter :: &
      !nx_block = 2880, & 
      !ny_block = 2619, &
      !km = 60

      integer (int_kind) i,j  

      real (r8) start_time, end_time,first_time

      real (r8), parameter ::                  &
      mwjfnp0s0t0 =   9.99843699e+2_r8 * p001, &
      mwjfnp0s0t1 =   7.35212840e+0_r8 * p001, &
      mwjfnp0s0t2 =  -5.45928211e-2_r8 * p001, &
      mwjfnp0s0t3 =   3.98476704e-4_r8 * p001, &
      mwjfnp0s1t0 =   2.96938239e+0_r8 * p001, &
      mwjfnp0s1t1 =  -7.23268813e-3_r8 * p001, &
      mwjfnp0s2t0 =   2.12382341e-3_r8 * p001, &
      mwjfnp1s0t0 =   1.04004591e-2_r8 * p001, &
      mwjfnp1s0t2 =   1.03970529e-7_r8 * p001, &
      mwjfnp1s1t0 =   5.18761880e-6_r8 * p001, &
      mwjfnp2s0t0 =  -3.24041825e-8_r8 * p001, &
      mwjfnp2s0t2 =  -1.23869360e-11_r8* p001

   !*** these constants will be used to construct the denominator

      real (kind=r8), parameter ::       &
      mwjfdp0s0t0 =   1.0e+0_r8,         &
      mwjfdp0s0t1 =   7.28606739e-3_r8,  &
      mwjfdp0s0t2 =  -4.60835542e-5_r8,  &
      mwjfdp0s0t3 =   3.68390573e-7_r8,  &
      mwjfdp0s0t4 =   1.80809186e-10_r8, &
      mwjfdp0s1t0 =   2.14691708e-3_r8,  &
      mwjfdp0s1t1 =  -9.27062484e-6_r8,  &
      mwjfdp0s1t3 =  -1.78343643e-10_r8, &
      mwjfdp0sqt0 =   4.76534122e-6_r8,  &
      mwjfdp0sqt2 =   1.63410736e-9_r8,  &
      mwjfdp1s0t0 =   5.30848875e-6_r8,  &
      mwjfdp2s0t3 =  -3.03175128e-16_r8, &
      mwjfdp3s0t1 =  -1.27934137e-17_r8
 

      integer (int_kind) ,intent(in) :: &
      k,                    &! depth level index
      kk                     ! level to which water is adiabatically displaced

      real (r8), dimension(nx_block,ny_block) ,optional, intent(out) :: & 
      RHOOUT,  &! perturbation density of water
      RHOFULL, &! full density of water
      DRHODT,  &! derivative of density with respect to temperature
      DRHODS    ! derivative of density with respect to salinity


      real (r8), dimension(nx_block,ny_block) ,intent(in) :: & 
      TEMPK,             &! temperature at level k
      SALTK               ! salinity    at level k
      
      real (r8), dimension(nx_block,ny_block) :: & 
      TQ,SQ,             &! adjusted T,S
      SQR,DENOMK,        &
      WORK1, WORK2, WORK3, WORK4  

      real(r8) twork1,twork2,twork3,twork4,TDENOMK 
        

      real (r8), dimension(km) :: & 
      tmin, tmax,        &! valid temperature range for level k
      smin, smax,        &! valid salinity    range for level k
      pressz              ! ref pressure (bars) at each level

     real (r8) :: p, p2, &! temporary pressure scalars 
      mwjfnums0t0, mwjfnums0t1, mwjfnums0t2, mwjfnums0t3,              &
      mwjfnums1t0, mwjfnums1t1, mwjfnums2t0,                           &
      mwjfdens0t0, mwjfdens0t1, mwjfdens0t2, mwjfdens0t3, mwjfdens0t4, &
      mwjfdens1t0, mwjfdens1t1, mwjfdens1t3,                           &
      mwjfdensqt0, mwjfdensqt2
 
 
      tmin =  -2.0_r8  ! limited   on the low  end
      tmax = 999.0_r8  ! unlimited on the high end
      smin =   0.0_r8  ! limited   on the low  end
      smax = 0.999_r8  ! unlimited on the high end


      call random_number(TQ)
      call random_number(SQ)
 
      p   = c10*pressz(kk)

      !***
      !*** first calculate numerator of MWJF density [P_1(S,T,p)]
      !***

      mwjfnums0t0 = mwjfnp0s0t0 + p*(mwjfnp1s0t0 + p*mwjfnp2s0t0)
      mwjfnums0t1 = mwjfnp0s0t1 
      mwjfnums0t2 = mwjfnp0s0t2 + p*(mwjfnp1s0t2 + p*mwjfnp2s0t2)
      mwjfnums0t3 = mwjfnp0s0t3
      mwjfnums1t0 = mwjfnp0s1t0 + p*mwjfnp1s1t0
      mwjfnums1t1 = mwjfnp0s1t1
      mwjfnums2t0 = mwjfnp0s2t0
       
       
      mwjfdens0t0 = mwjfdp0s0t0 + p*mwjfdp1s0t0
      mwjfdens0t1 = mwjfdp0s0t1 + p**3 * mwjfdp3s0t1
      mwjfdens0t2 = mwjfdp0s0t2
      mwjfdens0t3 = mwjfdp0s0t3 + p**2 * mwjfdp2s0t3
      mwjfdens0t4 = mwjfdp0s0t4
      mwjfdens1t0 = mwjfdp0s1t0
      mwjfdens1t1 = mwjfdp0s1t1
      mwjfdens1t3 = mwjfdp0s1t3
      mwjfdensqt0 = mwjfdp0sqt0
      mwjfdensqt2 = mwjfdp0sqt2

      call omp_set_num_threads(16)

      first_time = omp_get_wtime() 
      !dir$ assume_aligned SALTK: 64
      !dir$ assume_aligned RHOOUT: 64
      !dir$ assume_aligned RHOFULL: 64
      !dir$ assume_aligned DRHODT: 64 
      !dir$ assume_aligned RHOFULL: 64
      !dir$ assume_aligned DRHODS: 64
      !dir$ assume_aligned TEMPK: 64

      !$omp parallel default(none)shared(TQ,TEMPK,SQ,SALTK,WORK1,WORK2,WORK3,WORK4) &
      !$omp shared(SQR,DENOMK,RHOOUT,RHOFULL,DRHODS,DRHODT)&
      !$omp firstprivate(tmax,tmin,smax,smin,kk) &
      !$omp firstprivate(mwjfnums0t0,mwjfnums0t1,mwjfnums0t2,mwjfnums0t3) &
      !$omp firstprivate(mwjfnums1t0,mwjfnums1t1,mwjfnums2t0) &
      !$omp firstprivate(mwjfdens0t0,mwjfdens0t1,mwjfdens0t2,mwjfdens0t3) &
      !$omp firstprivate(mwjfdens0t4,mwjfdens1t0,mwjfdens1t1,mwjfdens1t3) &
      !$omp firstprivate(mwjfdensqt0,mwjfdensqt2) &
      !$omp private(TWORK1,TWORK2,TWORK3,TWORK4)

      !$omp do schedule(static)  
      do j=1,ny_block
      !dir$ ivdep
      !dir$ simd
      !dir$ vector 
      do i=1,nx_block

      TQ(i,j) = min(TEMPK(i,j),tmax(kk))
      TQ(i,j) = max(TQ(i,j),tmin(kk))
      SQ(i,j) = min(SALTK(i,j),smax(kk))
      SQ(i,j) = max(SQ(i,j),smin(kk))
      SQ(i,j)  = c1000*SQ(i,j)
      SQR(i,j) = sqrt(SQ(i,j))

      !WORK1(i,j)= c0
      !WORK2(i,j)= c0
      !WORK3(i,j)= c0 
      !WORK4(i,j)= c0
      !DENOMK(i,j)=c0
      RHOOUT(i,j)=c0
      DRHODT(i,j)=c0
      RHOFULL(i,j)=c0
      DRHODS(i,j)=c0 

      enddo
      enddo
      !$omp end do 
      !$omp end parallel 

      start_time=omp_get_wtime()

      !dir$ assume_aligned SALTK: 64
      !dir$ assume_aligned RHOOUT: 64
      !dir$ assume_aligned RHOFULL: 64
      !dir$ assume_aligned DRHODT: 64 
      !dir$ assume_aligned RHOFULL: 64
      !dir$ assume_aligned DRHODS: 64
      !dir$ assume_aligned TEMPK: 64 
      !$omp parallel default(none)shared(TQ,TEMPK,SQ,SALTK,WORK1,WORK2,WORK3,WORK4) &
      !$omp shared(SQR,DENOMK,RHOOUT,RHOFULL,DRHODS,DRHODT)&
      !$omp firstprivate(tmax,tmin,smax,smin,kk) &
      !$omp firstprivate(mwjfnums0t0,mwjfnums0t1,mwjfnums0t2,mwjfnums0t3) &
      !$omp firstprivate(mwjfnums1t0,mwjfnums1t1,mwjfnums2t0) &
      !$omp firstprivate(mwjfdens0t0,mwjfdens0t1,mwjfdens0t2,mwjfdens0t3) &
      !$omp firstprivate(mwjfdens0t4,mwjfdens1t0,mwjfdens1t1,mwjfdens1t3) &
      !$omp firstprivate(mwjfdensqt0,mwjfdensqt2) & 
      !$omp private(TWORK1,TWORK2,TWORK3,TWORK4,TDENOMK)
      
      !$omp do schedule(static)  
      do j=1,ny_block
      !dir$ simd 
      !dir$ ivdep
      !dir$ vector 
      do i=1,nx_block 


      TWORK1 = mwjfnums0t0 + TQ(i,j) * (mwjfnums0t1 + TQ(i,j) * (mwjfnums0t2 + &
              mwjfnums0t3 * TQ(i,j))) + SQ(i,j) * (mwjfnums1t0 +              &
              mwjfnums1t1 * TQ(i,j) + mwjfnums2t0 * SQ(i,j) )
      
      TWORK2 = mwjfdens0t0 + TQ(i,j) * (mwjfdens0t1 + TQ(i,j) * (mwjfdens0t2 +    &
           TQ(i,j) * (mwjfdens0t3 + mwjfdens0t4 * TQ(i,j) ))) +                   &
           SQ(i,j) * (mwjfdens1t0 + TQ(i,j) * (mwjfdens1t1 + TQ(i,j) * TQ(i,j) * mwjfdens1t3)+ &
           SQR(i,j) * (mwjfdensqt0 + TQ(i,j) * TQ(i,j) * mwjfdensqt2))

          TDENOMK = c1/TWORK2

      if (present(RHOOUT)) then
          RHOOUT(i,j)  = TWORK1 * TDENOMK
      endif

      if (present(RHOFULL)) then
          RHOFULL(i,j) = TWORK1 * TDENOMK
      endif

      if (present(DRHODT)) then
         TWORK3 = &! dP_1/dT
                 mwjfnums0t1 + TQ(i,j) * (c2*mwjfnums0t2 +    &
                 c3*mwjfnums0t3 * TQ(i,j)) + mwjfnums1t1 * SQ(i,j)

         TWORK4 = &! dP_2/dT
                 mwjfdens0t1 + SQ(i,j) * mwjfdens1t1 +               &
                 TQ(i,j) * (c2*(mwjfdens0t2 + SQ(i,j) * SQR(i,j) * mwjfdensqt2) +  &
                 TQ(i,j) * (c3*(mwjfdens0t3 + SQ(i,j) * mwjfdens1t3) +    &
                 TQ(i,j) *  c4*mwjfdens0t4))
        
          DRHODT(i,j) = (TWORK3 - TWORK1 * TDENOMK * TWORK4)* TDENOMK
      endif

      if (present(DRHODS)) then
         TWORK3 = &! dP_1/dS
                 mwjfnums1t0 + mwjfnums1t1 * TQ(i,j) + c2*mwjfnums2t0 * SQ(i,j)

         TWORK4 = mwjfdens1t0 +   &! dP_2/dS
                 TQ(i,j) * (mwjfdens1t1 + TQ(i,j) * TQ(i,j) * mwjfdens1t3) +   &
                 c1p5 * SQR(i,j) *(mwjfdensqt0 + TQ(i,j) * TQ(i,j) * mwjfdensqt2)

         DRHODS(i,j) = ( TWORK3 - TWORK1 * TDENOMK * TWORK4 ) * TDENOMK * c1000
     endif  
       enddo
       enddo
       !$omp end do

      !$omp end parallel         
      end_time = omp_get_wtime()

 
      print *,"loop time is", end_time - start_time
      print *,"total time is",end_time - first_time

      print *, sum(WORK1)
      print *, sum(WORK2)
      print *, sum(WORK3)
      print *, sum(WORK4)
      print *, sum(DRHODS)
      print *, sum(DRHODT)
      print *, sum(RHOOUT)
      print *, sum(RHOFULL)
      print *, sum(DENOMK)
       
end subroutine state

end program state_dummy
