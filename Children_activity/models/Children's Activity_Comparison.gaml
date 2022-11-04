/***
* Name: Children-activity v2
* Author: Jonatan Almagor
* Description: 
* Tags: Tag1, Tag2, TagN

***/


model Children_activity

global {
	/* File Import */
	string scale <- "53zones" among:["53zones","120zones"];
	file private_garden_file  <- file('../includes/Layers_glasgow/'+scale+'/Private_Garden_'+scale+'.shp') ;
	file road_shape_file      <- file('../includes/Layers_glasgow/'+scale+'/Road_'+scale+'.shp') ;
	file landuse_shape_file   <- file('../includes/Layers_glasgow/'+scale+'/Landuse_'+scale+'.shp');
	file my_landuse_file      <- csv_file('../includes/Layers_glasgow/land_use_table.csv',',',true);
	file food_drink_shapefile <- file('../includes/Layers_glasgow/'+scale+'/FoodDrink_'+scale+'.shp') ;
	file buildings_shapefile  <- file('../includes/Layers_glasgow/'+scale+'/Bld_'+scale+'.shp') ;
	file zone_shape_file      <- file('../includes/Layers_glasgow/'+scale+'//Zones_'+scale+'.shp') ;
	file school_shape_file    <- file('../includes/Layers_glasgow/'+scale+'/Prim_Edu_'+scale+'.shp') ;
	file leisure_shape_file   <-file('../includes/Layers_glasgow/'+scale+'/OS_Open_Leisure_Centre.shp') ;
	
	/* Setting up the Ecosystem */
	geometry shape <- envelope(road_shape_file);
	list<rgb> red_pallete <- brewer_colors("Reds");
	matrix data <- matrix(my_landuse_file);
	float step <-  #minute;
	int   t <- 60*7+48;   //minutes counter
	float current_hour <-7.8 ;
	int   days <- 1 ;
	int   week_day <- 1;
	graph the_graph; 
	int   nb_agents  <- length(children);
	bool  act_hours <- false ;//act hours are:15:00-19:00
	int   save_on_day <- 100;
	string save_file <- 'scenario';
	float max_visits <- 0.0;
    float min_visits <- 0.0;
	float max_less_min <- 1.0;
	
	
	//MVPA probabilities
	float mvpa_walk <- float(data[3,23]); // LU_MVPA_G & Line 23   
	float mvpa_shop <- float(data[3,7]); //7
	float mvpa_pe_girls <- float(data[3,19]); // LU_MVPA_Girls & Line19: MVPA PE Girls
	float mvpa_pe_boys <- float(data[4,19]);  // LU_MVPA_Boys & Line19: MVPA PE Girls
	float mvpa_arrival_girls <- float(data[3,9]); // School arrival for girls Column 3 Row 9
	float mvpa_arrival_boys  <- float(data[4,9]); // School arrival for girls Column 4 Row 9
	float mvpa_recess_girls  <- float(data[3,13]);// Recess girls column 3 row 13
	float mvpa_recess_boys   <- float(data[4,13]);// Recess girls column 4 row 13
	float mvpa_friends_in_girls <- float(data[3,24]); // Visiting friends indoors col 3 row 24
	float mvpa_friends_in_boys  <- float(data[4,24]); // Visiting friends indoors col 3 row 24
	float mvpa_fsa_girls <- float(data[3,26]);//26
	float mvpa_fsa_boys  <- float(data[4,26]);//26
	float mvpa_home_girls <- float(data[3,1]);//1
	float mvpa_home_boys  <- float(data[4,1]);//1
	float mvpa_school <- float(data[3,20]);//20
	
	
	// interventions
	int SC_inter <- 0; //minutes of additional school based activity
	bool include_fsa <- true; //agents dont have Foraml sport
	bool show_school_routes <- false;
	bool show_zones <- false;
	list<landuse_polygon> sport_poly; 
	list<landuse_polygon> afterSchool_act_poly;
	list<landuse_polygon> neigh_act_poly;
	list<building> residential;
	list<int> neigh_codes <- [2,3,14,15,18,21];
	list<int> after_school_codes <- [2,3,14,15,18];
	
	
	// counters
	int count_a_s <- 0;//counting children doing after school activity
	int count_n_p <- 0;//counting neigh play
	int count_g_a <- 0;//counting grarden
	int count_s_a <- 0;//counting shoping
	int per_walking;
	int count_friends_out;
	int count_friends_in;
	int count_fsa;
	list<int> list_neigh_play;
	int mvpa_avg<-0;
	int mvpa_std<-0;
	int mvpa_recent_avg<-0;
	
	
	//proba of activities
	float f_m<-2/5;//prob to meet a friend 
	float a_s<-2/5; //prob for after school activity on the route home 
	float n_p<-1/5; //prob playing at the neighborhood
	float f_o<-0.5; //prob of friends to goout
	float s_a<-1/5;//prob shopping 
	float g_a<-0.0; //prob for garden play
	float imp_kids<-0.1;
	float imp_f<-0.3; //impact of friends on my_activeness
	string travel_mode<-"usual" among:["usual", "active_school","walk_all"];
	graph child_graph<-([]);
	string optimizer_type <- "AStar" among: ["NBAStar", "NBAStarApprox", "Dijkstra", "AStar", "BellmannFord", "FloydWarshall"];
	/* types of optimizer (algorithms) can be used for the shortest path computation:
	 *    - Dijkstra: ensure to find the best shortest path - compute one shortest path at a time: https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
	 * 	  - BellmannFord: ensure to find the best shortest path - compute one shortest path at a time: https://en.wikipedia.org/wiki/Bellman-Ford_algorithm
	 * 	  - AStar: ensure to find the best shortest path - compute one shortest path at a time: https://en.wikipedia.org/wiki/A*_search_algorithm
	 *    - NBAStar: the default one - ensure to find the best shortest path - compute one shortest path at a time: http://repub.eur.nl/pub/16100/ei2009-10.pdf
	 *    - NBAStarApprox : does not ensure to find the best shortest path - compute one shortest path at a time: http://repub.eur.nl/pub/16100/ei2009-10.pdf
	 *    - FloydWarshall: ensure to find the best shortest path - compute all the shortest paths at the same time (and keep them in memory): https://en.wikipedia.org/wiki/Floyd-Warshall_algorithm
	 */
	init { 
		//seed<-10.0; enable if you want to keep the same seed for every simulation
		date started<-date("now"); write "Start initialise:"+started;
		date tmp_date<- date("now");
		do create_layers;         //write "create layers: "+ (date("now")-tmp_date);tmp_date<- date("now");
		do create_children;       //write "create children: "+ (date("now")-tmp_date);tmp_date<- date("now");
		do assign_schools;        //write "assign schools: "+ (date("now")-tmp_date);tmp_date<- date("now");
		do cal_sch_walk_prob;     //write "assign prob walk to school: "+ (date("now")-tmp_date);tmp_date<- date("now");		
		do assign_garden_actlist; //write "assign garden+act list: "+ (date("now")-tmp_date);tmp_date<- date("now");
	    do assign_neigh_lu;       //write "assign neigh lu: "+ (date("now")-tmp_date);tmp_date<- date("now");
		do assign_routehome_lu;   //write "assign route home lu: "+ (date("now")-tmp_date);tmp_date<- date("now");
		do assign_shops;      	  //write "assign shops: "+ (date("now")-tmp_date);
		do assign_fsa; 			  //write "assign fsa: "+ (date("now")-tmp_date);		
		do assign_friends; 		  //write "assign freinds: "+ (date("now")-tmp_date);				
		nb_agents <- length(children); //write "Children: "+nb_agents+ " Houses: "+length(building)+" in: "+ (((date("now")-started)/60)) with_precision 1+" min" color:#blue;	
	}
	
	/* ----------------------
	 * Global action and reflex
	 * ---------------------- */

	action create_layers{
		create private_garden from: private_garden_file with:[area::int(read("area")), code::int(read("lu_code")),
		lu_name::string(read("Land_use")), perimeter::int(read("perimeter")), poly_id::int(read("Poly_ID"))	];
		
		create schools from: school_shape_file with:[id_catch::int(read("ID_catch"))];
		
		create road from: road_shape_file ;
		
		create zone from: zone_shape_file with:[
			dataZone::string(read("DataZone")),nb_children::int(1.5*int(read("8_9"))),pop::int(read("All_age")),nm_hh::int(read("House_nm")), crimeRate::int(read("CrimeRate")),
			over16::int(read("over16")),
			prob_social::[float(read("de25_44")),float(read("c2_25_44")),float(read("c1_25_44")),float(read("ab25_44")) ],
			simd::int(read("Quintile")), 
			norm_crime::float(read("norm_crime")), // unit of norm_crime , 1 unit=1 SD
			AB_car_prob::[float(read("AB_NO_CAR")),float(read("AB_1CAR")),float(read("AB_2CAR"))], //Least deprived
			C1_car_prob::[float(read("C1_NO_CAR_")),float(read("C1_1CAR")),float(read("C1_2CAR"))],
			C2_car_prob::[float(read("C2_NO_CAR_")),float(read("C2_1CAR")),float(read("C2_2CAR"))],
			DE_car_prob::[float(read("DE_NO_CAR_")),float(read("DE_1CAR")),float(read("DE_2CAR"))]];  //Most deprived
			
			ask zone where(each.nb_children=0){
				do die;
			}
				
		create landuse_polygon from: landuse_shape_file with: [area::int(read("area")), code::int(read("lu_code")),
				perimeter::int(read("perimeter")),poly_id::int(read("Poly_ID"))];
		create landuse_polygon from:leisure_shape_file with: [code::26, lu_name::"Leisure"];//ading the leisure centers to land use layer
		
		ask landuse_polygon{   
			mvpa_prob_G <- float(data[3,code]); 
			mvpa_prob_B <- float(data[4,code]);
			lu_name     <- string(data[2,code]);
			color       <- rgb(int(data[5,code]),int(data[6,code]),int(data[7,code]));
			if [14,15,21,26,20] contains code {add self to:sport_poly;}
			if neigh_codes contains code {add self to: neigh_act_poly;}
			if after_school_codes contains code {add self to: afterSchool_act_poly; }
		}
		ask neigh_act_poly where([2,3] contains each.code and each.area<1000){ //remove residential amenity  with area<1000
			remove self from:neigh_act_poly;	
		}
		
		ask afterSchool_act_poly where([2,3] contains each.code and each.area<1000) {
			remove self from:afterSchool_act_poly;
		}
		
		create food_drink from:food_drink_shapefile with: [density::int(read("density")),poly_id::int(read("Poly_ID")) ];// number of shops in buffer 100 around the shop
		
		the_graph <- as_edge_graph(list(road));
		the_graph <- the_graph with_optimizer_type optimizer_type; //allows to choose the type of algorithm to use compute the shortest paths
	 	
	 	create building from: buildings_shapefile with: [
			 type::string(read ("type")), zone::string(read ("zone")),area::int(read ("area")), 
			 x_cor::int(read ("X_cor")),y_cor::int(read ("Y_cor")),height::int(read ("Height")),
			 id_catch::int(read ("Id_catch")), poly_id::int(read("Poly_ID")),walk_quant::int(read("walk_quant"))];
		 
		residential <- building where(each.type='Home');
	}
	
	action create_children {
		int counting <- 0;
		ask zone   {
			list<building> zone_homes <- residential where (each.zone=self.dataZone);
	 		create children number: nb_children {
				counting<-counting+1;
				if counting/1000=int(counting/1000){
					write counting;	
				}
				my_zone  <- myself;
				my_home  <- one_of(zone_homes);
				id_catch <- my_home.id_catch;
				x_cor    <- my_home.x_cor;
				y_cor    <- my_home.y_cor;
				location <- any_location_in(my_home);
				my_social_status    <- rnd_choice(my_zone.prob_social) + 1;  //4 social level 1,2,3,4 (1-poorest 4-richest)
				if my_social_status = 1 {num_car <- rnd_choice(my_zone.DE_car_prob);} //assign number of car based on the distribution for DE class in the data zone
				if my_social_status = 2 {num_car <- rnd_choice(my_zone.C2_car_prob);}
				if my_social_status = 3 {num_car <- rnd_choice(my_zone.C1_car_prob);}
				if my_social_status = 4 {num_car <- rnd_choice(my_zone.AB_car_prob);}
				my_crime <- myself.norm_crime;
				my_simd  <- myself.simd;
				my_simd_imp <- my_simd = 5? 1.0: (my_simd = 4? 0.9:(my_simd = 3? 0.8:(my_simd =2? 0.7:0.6))); 
							// impact of crime of outplay no impact if crime<=0 
							// low impact-80% 0-0.7, medium 60% [0.7-1.3] high 40% >=1.3
				my_neigh_prob <- min(1, n_p * outplay * my_simd_imp);
				}
			}	
	}
	
	action assign_schools {
		ask children parallel:true  {
			list<schools> my_school_candidates <- schools where(each.id_catch=self.id_catch) sort_by (each distance_to self);
			my_school <- length(my_school_candidates)> 2 ? my_school_candidates[rnd(0,2)]: one_of(my_school_candidates) ; 
			
			if my_school=nil{
				my_school_candidates <- schools sort_by (each distance_to self );
				my_school <-my_school_candidates[0];	
				}
			}
			
		ask schools parallel:true  {
			nb_pupils<-length(children where(each.my_school=self));
		}
		
		ask children where(each.my_school.nb_pupils<25) parallel:true {
			if num_car=0{
				list<schools> my_school_candidates<-schools where(each.nb_pupils>=25) sort_by (each distance_to self );	
				my_school <- my_school_candidates[0];	
				}
			if num_car>0{
				list<schools> my_school_candidates<-schools where(each.nb_pupils>=25) sort_by (each distance_to self );	
				my_school <- my_school_candidates[rnd(0,2)];	
				}	
			}
			
		ask schools parallel:true  {
			nb_pupils <- length(children where(each.my_school=self));
			avg_my_social_status <- (children where(each.my_school=self) mean_of(each.my_social_status)) with_precision 2;
			}	
	}


	action cal_sch_walk_prob {
		ask children parallel:true {
			school_route<-path_between (the_graph, my_home, my_school);
			if school_route=nil{
				do die;
				}
			dis_school <-int(school_route.edges sum_of (each.perimeter));//distance to school based on roads
			if dis_school<=300 or num_car<1{
				school_walk_prob<-1.0;
				}
			else{
				float coef_dis<- -1.6*ln(dis_school/250)+0.056;  //-1.1*ln(dis/250)+0.056
				float coef_walkb<-my_home.walk_quant=1?0: -0.035*(my_home.walk_quant-1)^2+0.0678*(my_home.walk_quant-1)-0.8382;// -0.0292*(walk-1)^2+0.0678*(walk-1)-0.838
				float winter_coef<- -0.3;
				float logit_0<- -5.807733-(-1.427+coef_walkb+coef_dis+winter_coef);   //cut1-(-1.427+coef_walk+coef_dis)
				float logit_1_2<- -4.922359-(-1.427+coef_walkb+coef_dis+winter_coef);////cut2-(-1.427+coef_walk+coef_dis)
				float logit_3_4<- -3.9048-(-1.427+coef_walkb+coef_dis+winter_coef);////cut3-(-1.427+coef_walk+coef_dis) ******cu1,cut2,cut3 are coefficient from ordinal logistic regression -1.427 is the coef of latitude- impact of weather in Glasgow 
				float cum_prob0<- exp(logit_0)/(1+exp(logit_0));
				float cum_prob_1_2<- exp(logit_1_2)/(1+exp(logit_1_2));
				float cum_prob_3_4<- exp(logit_3_4)/(1+exp(logit_3_4));
				float prob0<-cum_prob0;
				float prob1_2<-cum_prob_1_2-cum_prob0;
				float prob_3_4<-cum_prob_3_4-cum_prob_1_2;
				float prob_5<-1-cum_prob_3_4;
				int cat<-rnd_choice(prob0,prob1_2,prob_3_4,prob_5); //One of the number of active walking categories is selected  
				school_walk_prob<-([0,rnd(0.2,0.4),rnd(0.4,0.8),rnd(0.8,1.0)][cat])  ;		
				}
				if dis_school>2500 and num_car>0{
					school_walk_prob<-0.0;	
					}	
				}
		ask zone parallel:true {
			avg_dis_sh <- int(children where(each.my_zone=self) mean_of (each.dis_school));
		}	
	}
	
	action assign_garden_actlist{
	 	ask children parallel:true{
	 		my_garden<-private_garden where(self distance_to each<25) closest_to self;      
			act_list<-my_garden=nil?[1,2]:[1,2,3]; //list for activities from home 1-shoping, 2-neigh, 3-graden (incase the agent has one)
		 }	
	}
	
	action assign_neigh_lu{
		ask children parallel:true{
			list<landuse_polygon> extended_neigh_poly<-neigh_act_poly where(each distance_to self <=800);  //selecting only land use within 800 meter
			extended_neigh_poly<-extended_neigh_poly sort_by (each distance_to self); 
			list<landuse_polygon> temp_list;
			list<int> neigh_poly_codes<-extended_neigh_poly collect(each.code);
			loop s over: neigh_codes{
				if neigh_poly_codes contains s {
					int k<-min(3,length(extended_neigh_poly where(each.code=s)));//taking the max 5 polygon of each type in 800 meter around the house
					loop times:k{
						landuse_polygon this_poly<-extended_neigh_poly first_with(each.code=s);
						temp_list<<this_poly;
						remove this_poly from: extended_neigh_poly;	
						}				
					}		
				}
			neigh_poly<-temp_list;
			ask neigh_poly{
				path route<-path_between(the_graph, self,myself);
				dis_child<-int(route.edges sum_of (each.perimeter));
				}
			neigh_poly<-neigh_poly sort_by(each.dis_child);
			neigh_map<-neigh_poly as_map(each::each.dis_child);//the keys is the polygon, the elment is the distance			
			}	
		}
	
	action assign_routehome_lu {
		ask children parallel:true{
			geometry polyline_home<-polyline(school_route.edges);
			after_sc_poly<-afterSchool_act_poly where(distance_to(each,polyline_home) <500); //land use within 500 meter around the route home
			ask after_sc_poly{
				path route <- path_between(the_graph, self,myself.my_school);//between school and the lu
				path route1 <- path_between(the_graph, self,myself.my_home);//between lu to home
				if route = nil or route1 = nil {
					remove self from:myself.after_sc_poly;
				}
				else{
					added_dis <- int(route.edges sum_of (each.perimeter)+ route1.edges sum_of (each.perimeter)-myself.dis_school);	//in this case dis_child is the added distance
					if added_dis >= 500 {remove self from:myself.after_sc_poly;}	
					}	
				}	
			if after_sc_poly=nil{do die;}
			after_sc_map<-after_sc_poly as_map(each::each.dis_child);//the keys is the polygon, the elment is the distance	
		}
	}
	
	action assign_shops {
		ask children parallel:true{
			list_food_drink<-food_drink where(each distance_to self<1000);
			int tmp<-length(list_food_drink);
			if tmp>0{
				list_food_drink<-copy_between (list_food_drink,0,min(tmp,9));
				list_food_drink<-(reverse(list_food_drink sort_by(each.density)));	
				}
			list_food_drink<-(reverse(list_food_drink sort_by(each.density)));		
		}
	}
	
	action assign_fsa {
		ask children  {//assign formal sport activities
			if include_fsa=false{num_sport<-0;}
			else{
				if my_social_status = 1 {num_sport<- rnd_choice([0.5, 0.2, 0.15,0.1,0.03, 0.02]);}
				if my_social_status = 2 {num_sport<- rnd_choice([0.4, 0.25, 0.2, 0.1,0.03, 0.02]);}
				if my_social_status = 3 {num_sport<- rnd_choice([0.3, 0.18, 0.3, 0.075,0.075, 0.07]);}
				if my_social_status = 4 {num_sport<-rnd_choice([0.15,0.2,0.35,0.07,0.07,0.14]);}	
					}
			if num_sport>0  {
				create sport_activity number:num_sport {
					int sport_type<-one_of([0,1,2]);//33% sport in Leisure center, 33% in sport fields, 33% in schools
					if sport_type=0{act_poly<-one_of(sport_poly where(each distance_to myself <1500 and each.code=26));if act_poly=nil{sport_type<-one_of([1,2]);}}//sport in leisure center 
					if sport_type=1{act_poly<- one_of(sport_poly where(each distance_to myself <1500 and [14,15,21]contains each.code));if act_poly=nil{sport_type<-2;}}//team sport in play fields
					if sport_type=2{act_poly<-one_of(sport_poly where(each distance_to myself <1500 and each.code=20));}//sport activity in school
					my_child<-myself;
					type<-"sport";
					hour<-one_of([16,17,18]);
					time<-60;
					code<-26;//code of FSA
					mvpa<-myself.gender="boy"? mvpa_fsa_boys:mvpa_fsa_girls;
					add self to: myself.formal_sport_act; //ataching the activity to my variables
					}
					list<int>tmp_days<-[1,2,3,4,5];
						ask formal_sport_act{
							day<-one_of (tmp_days);//the day of activity, if few sport activties than its a list of the activity days
							remove day from:tmp_days;	
						} 
					}						  		
				}		
	}
	
	action assign_friends {
		ask children {
			add node(self) to: child_graph;
			list<children> wide_friends <- 7 among (children where(each.my_school=self.my_school and each.gender=self.gender)) + 3 
			among (children where(each.my_school=self.my_school and each.gender!=self.gender)) - self;
			list<children> tmp<-3 among (wide_friends);
			loop f over: tmp {
				if child_graph contains_edge(self::f)=false and child_graph contains_edge(f::self)=false {
					child_graph<-child_graph add_edge(self::f);		
			} 
		}	
	}
	
	ask children parallel:true{
		my_best_friends <- list<children>(child_graph neighbors_of(self));
		num_friends <- length(my_best_friends);
		//fit_dif<-my_activeness-my_best_friends mean_of(each.my_activeness);	
		act_list<-my_garden=nil?[1,2]:[1,2,3];//updating the list of activities from home shoping=1, neigh=2,garden=3
		
		}
	}
	
	action write_lu_mvpa_values{
		//loop on the matrix rows (skip the first header line)
		loop i from: 0 to: data.rows-1 {
			//loop on the matrix columns
			if data[1,i]!=''{
				write " " + data[2,i] + "[" + data[1,i]+"]"+ " Nm: "+ length (landuse_polygon where (each.code=int(data[1,i])))+ 
				 " MVPA: " + data[5,i];			
			}
			
		}
		
	}

	reflex time_counter {
	    t<-t+1;
		current_hour<- float((t)mod 1440)/60;
		 if current_hour=9.5{
		 	per_walking<- int(100*length(children where (each.trans_mode = 1))/nb_agents) ;
	    	t<-15*60;//time jumps from 09:00 to 15:00
			current_hour<-15.0; 	
	    }
		act_hours<- current_hour<=19 and current_hour>15? true:false;
		ask landuse_polygon{
				visits_per_day<-count_visits/(days);
			}
		if current_hour>21 {
			t <- 8*60;
			current_hour <- 8.00;	
			days <- days+1;
			week_day<-week_day+1=6? 1: week_day+1;
			add count_n_p to: list_neigh_play;
			count_a_s <-0; //after school
			count_g_a <-0; //garden
			count_n_p <-0; //neigh play
			count_s_a <-0; //shopping
			count_friends_out <- 0; //friends playing outdoor
			count_friends_in <- 0; //friends playing indoor
			count_fsa <- 0; //formal sport
			
			
			ask schools{
				per_meeting <- nb_pupils>0? (length(children where(each.my_school=self and each.a_s_play))/nb_pupils) with_precision 2 : 0;
				add per_meeting to: list_meeting;
				avg_list_meeting<-mean(list_meeting) with_precision 2;
			}
			do update_children;
			ask zone{
				do zone_mvpa;
			}
			mvpa_avg <- int(children mean_of (each.avg_mvpa) with_precision 1) ;
			//mvpa_recent_avg<-children mean_of (each.avg_mvpa_recent) with_precision 1 ;//mvpa of the last two weeks
			mvpa_std <- int(standard_deviation (children collect(each.avg_mvpa)) with_precision 1);
			
		}
	
	 }
	 
reflex friends_meeting when: current_hour=8.0{
	ask children{
		if formal_sport_act!=nil { 
			today_sport <-one_of(formal_sport_act where (each.day=week_day));
		}
		have_formal<-today_sport=nil? false:true; //check if any formal act_today	
		if have_formal=false{
				meeting_friends<-flip(f_m)?true:false;	
			}
		}
	ask children where (each.meeting_friends){
		goto_friend<- one_of (my_best_friends where(each.meeting_friends=false and each.have_formal=false));
			if goto_friend!=nil{
				add self to:goto_friend.host_friends;
				}
			else{meeting_friends<-false;}			
		}	
		
   	ask children where(length(each.host_friends)!=0){
   		meeting_friends<-true;	
   		meet_hour<-15.5+rnd(0,10)*0.25;//at this time the host will invoke the meeting while updating the other friends 
   	}
   	
}	 


reflex save_simulation when:days=save_on_day and current_hour=8.0{
		write "saving simulation+"+self+ date("now");
		ask children parallel:true {do collect_mvpa;}
		ask zone parallel:true{do zone_stat;}	
		float zero_to_30    <- length(children where(each.avg_mvpa<=30))/nb_agents with_precision 2;
		float thirty_to_40  <- length(children where(each.avg_mvpa>30 and each.avg_mvpa<40))/nb_agents with_precision 2;
		float forty_to_50   <- length(children where(each.avg_mvpa>=40 and each.avg_mvpa<50))/nb_agents with_precision 2;
		float fifty_to_60   <- length(children where(each.avg_mvpa>=50 and each.avg_mvpa<60))/nb_agents with_precision 2;
		float sixty_to_70   <- length(children where(each.avg_mvpa>=60 and each.avg_mvpa<70))/nb_agents with_precision 2;
		float seventy_to_80 <- length(children where(each.avg_mvpa>=70 and each.avg_mvpa<80))/nb_agents with_precision 2;
		float Eighty_to_90  <- length(children where(each.avg_mvpa>=80 and each.avg_mvpa<90))/nb_agents with_precision 2;
		float ninty_over    <- length(children where(each.avg_mvpa>=90))/nb_agents;
		float per_avg_under_sixty <- zero_to_30 + thirty_to_40+forty_to_50+fifty_to_60;
		
		int mvpa_my_social_status1 <- int(children where(each.my_social_status=1) mean_of (each.avg_mvpa));
		int mvpa_my_social_status2 <- int(children where(each.my_social_status=2) mean_of (each.avg_mvpa));
		int mvpa_my_social_status3 <- int(children where(each.my_social_status=3) mean_of (each.avg_mvpa));
		int mvpa_my_social_status4 <- int(children where(each.my_social_status=4) mean_of (each.avg_mvpa));
		int walk_my_social_status1 <- int(children where(each.my_social_status=1) mean_of (each.avg_walk));
		int walk_my_social_status2 <- int(children where(each.my_social_status=2) mean_of (each.avg_walk));
		int walk_my_social_status3 <- int(children where(each.my_social_status=3) mean_of (each.avg_walk));
		int walk_my_social_status4 <- int(children where(each.my_social_status=4) mean_of (each.avg_walk));
		
		float R_mvpa_my_social_status <- (children collect(each.avg_mvpa)) correlation (children collect(each.my_social_status)) with_precision 2 ;
		float R_mvpa_sport <- (children collect(each.avg_mvpa)) correlation (children collect(each.num_sport)) with_precision 2;
		float R_mvpa_crime <- (children collect(each.avg_mvpa)) correlation (children collect(each.my_zone.norm_crime)) with_precision 2 ;
		float R_mvpa_walk  <- (children collect(each.avg_mvpa)) correlation (children collect(each.avg_walk)) with_precision 2 ;
		float R_mvpa_fit   <- (children collect(each.avg_mvpa)) correlation (children collect(each.my_activeness)) with_precision 2 ;
		float R_mvpa_outplay <- (children collect(each.avg_mvpa)) correlation (children collect(each.outplay)) with_precision 2 ;
		float R_mvpa_dmin_outplay <- (children collect(each.avg_mvpa))  correlation (children collect(each.daily_od)) with_precision 2 ;
		float R_simd <- (children collect(each.avg_mvpa))  correlation (children collect(each.my_simd)) with_precision 2 ;
		float R_car  <- (children collect(each.avg_mvpa))  correlation (children collect(each.num_car)) with_precision 2 ;
		float R_friends <- (children collect(each.avg_mvpa))  correlation (children collect(each.num_friends)) with_precision 2 ;
		float avg_mvpa <- children mean_of (each.avg_mvpa);
		float avg_mvpa_boy <- children where(each.gender="boy") mean_of (each.avg_mvpa);
		float avg_mvpa_girl <- children where(each.gender="girl") mean_of (each.avg_mvpa);
		int mvpa_home <- int(children mean_of(each.mvpa_home)) ; //home
		int mvpa_sc<-int(children mean_of(each.mvpa_sc)) ; //school
		int mvpa_road<- int(children mean_of(each.mvpa_road)); //road
		float mvpa_play_field<-children mean_of(each.mvpa_play_field) ; //playing fields
		int mvpa_home_girlsarden<-int(children mean_of(each.mvpa_home_girlsarden)) ; //home Garden
		float mvpa_park<-children mean_of(each.mvpa_park) ;//Park
		float mvpa_PG<-children mean_of(each.mvpa_PG) ;//Public garden
		float mvpa_amenity<-children mean_of(each.mvpa_amenity) ;//Amenity space
		float mvpa_shops<-children mean_of(each.mvpa_shops) ;//shops
		float mvpa_friends_home<-children mean_of(each.mvpa_friends_home); //friends home
		int mvpa_fsa<-int(children mean_of(each.mvpa_fsa)) ;//FSA
		int mvpa_total_outdoor<-int(children mean_of(each.daily_od_mvpa)) ;//total outdoor
		int fsa_time<-int(children mean_of(each.lu_list[26]/days));//FSA
		int OD_time<-int(children mean_of(each.daily_od)) ;////total outdoor
		int SD_mvpa<-int((children variance_of (each.avg_mvpa))^0.5);
		float per_daily_sixty<-float(length (children where(each.per_days_sixt>=0.9)));
		
		
		string file_name<-"../includes/results/"+save_file;
		save zone type: "csv" to: file_name+"/zone/Sc_int"+SC_inter+travel_mode+"/"+"Neigh_play"+n_p+"/zone"+"SC"+SC_inter+"np"+n_p+"imp_k"+imp_kids+self+ ".csv" ; 
		save children type: "csv" to: file_name+"/children/Sc_int"+SC_inter+"_"+travel_mode+"/"+"Neigh_play"+n_p+"/children"+"SC"+SC_inter+"np"+n_p+"imp_k"+imp_kids+self+ ".csv" ; 
		list tmp<-["s_name",travel_mode,imp_f,SC_inter,n_p,f_m,imp_kids,avg_mvpa,SD_mvpa,per_avg_under_sixty,per_daily_sixty,avg_mvpa_boy,avg_mvpa_girl, zero_to_30,thirty_to_40,forty_to_50,fifty_to_60,sixty_to_70,seventy_to_80,Eighty_to_90,ninty_over,
				mvpa_my_social_status1,mvpa_my_social_status2,mvpa_my_social_status3,mvpa_my_social_status4,walk_my_social_status1,walk_my_social_status2,walk_my_social_status3,walk_my_social_status4,
				R_mvpa_my_social_status,R_mvpa_sport,R_mvpa_crime,R_mvpa_walk,R_mvpa_fit,R_mvpa_outplay, R_mvpa_dmin_outplay,R_simd,R_car,R_friends,
				mvpa_home,mvpa_sc,mvpa_road,mvpa_play_field,mvpa_park,mvpa_PG,mvpa_amenity,mvpa_shops,mvpa_friends_home,mvpa_fsa,mvpa_total_outdoor,mvpa_home_girlsarden,
				fsa_time,OD_time];
		save tmp to:file_name+"/Sim_stat/sim_stat.csv" type: "csv" rewrite:false header:true;
		
	}
	
action write_headings{
		save list(["S_name","travel_mode","imp_friends","school_inter","Neigh_play","friend_meet","imp_kids",
		            "avg_mvpa","SD_mvpa","per_avg_under_sixty","per_sixty_daily","mvpa_boys","mvpa_girls",
		            "0_30", "30_40","40_50","50_60","60_70","70_80","80_90","more90",
		            "mvpa1","mvpa2","mvpa3","mvpa4","walk1","walk2","walk3","walk4",
					"R_my_social_status","R_sport","R_crime","R_walk", "R_fit","R_outplay","R_min_outplay","R_simd","R_car","R_friends",
					"PA_home","PA_sc","PA_road","PA_Pfield","PA_park","PA_PG","PA_amenity","PA_SHOP","PA_F_home","PA_FSA","PA_OD","PA_H_garden","fsa_time","OD_time"])	
					to: "../includes/results/"+save_file+"/Sim_stat/sim_stat.csv" type: "csv" rewrite:false header:true;	
	}
	
action update_children{
	ask children{
		avg_walk<-lu_list[23]/(days-1);
		daily_od<- int((lu_list[2]+lu_list[3]+lu_list[14]+lu_list[15]+lu_list[18]+lu_list[21])/(days-1));
		daily_od_mvpa<-int((list_lu_mvpa[2]+list_lu_mvpa[3]+list_lu_mvpa[14]+list_lu_mvpa[15]+list_lu_mvpa[18]+list_lu_mvpa[21])/(days-1));
		a_s_play<-false;  
		add tot_mvpa to:list_mvpa;
		avg_mvpa<-mean(list_mvpa);
		per_days_sixt<-length(list_mvpa where (each>=60))/length(list_mvpa);
		int last<-length(list_mvpa)-1;
		int start<-max(0,last-30);
		//avg_mvpa_recent<-mean(copy_between (list_mvpa,start,last));//average MVPA in the last month
		tot_mvpa<-0;
		act_list<-my_garden=nil?[1,2]:[1,2,3];//updating the list of activities from home shoping=1, neigh=2,garden=3
		meeting_friends<-false;
		goto_friend<-[];
		host_friends<-[];
		with_friends<-false;
		meet_hour<-[];
			
		}			
	} 

} // end of global





species private_garden{
	int poly_id;
	rgb color<-rgb(204,255,153);
	int area;
	int perimeter;
	float mvpa_prob;
	string lu_name;
	int code;	
	aspect base {
		draw shape color: color ;
	}	
}
species schools{
	int id_catch;
	int pe_day<-rnd(4)+1;
	rgb color <- rgb(255,0,127);
	float per_meeting;
	list<float> list_meeting;
	float avg_list_meeting;
	int   nb_pupils;
	float avg_my_social_status;
	float avg_mvpa;
	aspect base {
		draw shape border:#black color: color ;
		draw string(avg_my_social_status) at:point(self) font: font('Default', 12, #bold) color:#black;
	}
	reflex update_mvpa when:current_hour=8.0{
		avg_mvpa<- children where(each.my_school = self) mean_of(each.avg_mvpa);
				
		
	}	
}
species zone{
	string dataZone; 
	int nb_children; 
	int pop;
	int over16; 
	int nm_hh;
	list<float> AB_car_prob; //list of car prob [no_car, one_car,two_cars]
	list<float> C1_car_prob; //list of car prob [no_car, one_car,two_cars]
	list<float> C2_car_prob; //list of car prob [no_car, one_car,two_cars]
	list<float> DE_car_prob; //list of car prob [no_car, one_car,two_cars]
	list<float> prob_social; //list of fraction of each class in the zone [DE,C2,C1,ab]
	int simd; 
	float crimeRate;
	float norm_crime;
	int   avg_dis_sh;
	int   neigh_play <-0;//count children playing in neigh
	float daily_play_per_child<-0.0;
	float avg_FSA;
	float avg_walk;
	float daily_OD;
	float zone_mvpa;
	float mvpa_home; //home
	float mvpa_sc ; //school
	float mvpa_road; //road
	float mvpa_play_field ; //playing fields
	float mvpa_home_girlsarden ; //home Garden
	float mvpa_park;//Park
	float mvpa_PG ;//Public garden
	float mvpa_amenity ;//Amenity space
	float mvpa_shops ;//shops
	float mvpa_friends_home; //friends home
	float mvpa_fsa ; //FSA
	float mvpa_total_outdoor;//total outdoor	
	
	reflex count_neigh_play when: current_hour=8.0{
		daily_play_per_child<-neigh_play/(nb_children*days);	
	}
	aspect default{
		if days>1 and show_zones  {
			draw shape color: zone_mvpa<mvpa_avg-3? #green:(zone_mvpa>mvpa_avg+3?#brown:(zone_mvpa>=mvpa_avg? #orange: #blue)) border:#black;	
			draw "MVPA: " +zone_mvpa with_precision 1 at:location color:#black;
		}
		else if  show_zones {
			draw shape.contour+4 color:#brown;	
		}
		
	}	
	action zone_mvpa {
		zone_mvpa<-children where(each.my_zone=self) mean_of (mean(each.list_mvpa));	
	}
	action zone_stat{
	list<children> my_children<-children where(each.my_zone=self); 
	avg_FSA<-my_children mean_of (each.num_sport);
	avg_walk<-my_children mean_of (each.avg_walk);
	daily_OD<-my_children mean_of (each.daily_od);
	mvpa_home<-my_children mean_of(each.mvpa_home) ; //home
	mvpa_sc<-my_children mean_of(each.mvpa_sc) ; //school
	mvpa_road<- my_children mean_of(each.mvpa_road); //road
	mvpa_play_field<-my_children mean_of(each.mvpa_play_field) ; //playing fields
	mvpa_home_girlsarden<-my_children mean_of(each.mvpa_home_girlsarden) ; //home Garden
	mvpa_park<-my_children mean_of(each.mvpa_park) ;//Park
	mvpa_PG<-my_children mean_of(each.mvpa_PG) ;//Public garden
	mvpa_amenity<-my_children mean_of(each.mvpa_amenity) ;//Amenity space
	mvpa_shops<-my_children mean_of(each.mvpa_shops) ;//shops
	mvpa_friends_home<-my_children mean_of(each.mvpa_friends_home); //friends home
	mvpa_fsa<-my_children mean_of(each.mvpa_fsa) ;//FSA
	mvpa_total_outdoor<-my_children mean_of(each.daily_od_mvpa) ;//total outdoor	
	}
}
species sport_activity{
	string type;
	int day;
	int hour;
	int time;
	landuse_polygon act_poly;
	float mvpa;
	int code;
	children my_child;
}
species social_act{
	list<int> day;
	int time;
	landuse_polygon act_poly;
	children my_child;	
}

species road  {
	float speed_coef ;
	//int current_child_count<-0 ;//update:length(children inside(self));
	//int child_minutes<-0;
	aspect default{
			draw shape color:#black;			
	}
} 

species food_drink{
	int poly_id;
	int density;
	aspect default{
		draw square(12) at:point(self) border: #black color: #brown;
	}	
}	
	
species landuse_polygon{
	int poly_id;
	rgb color;
	int area;
	int perimeter;
	float mvpa_prob_G;
	float mvpa_prob_B;
	string lu_name;
	int code;
	int added_dis;	
	float rank;
	int count_visits;
	float visits_per_day;
	int child_count;
	int dis_child;//a parameter that used to calculate dis to the agent
	
	aspect base {
		draw shape color: color ;
	}

}

species building { 
	string type; // Home,School, Other use
	string zone;
	int poly_id;
	int area;
	int height;
	int x_cor;
	int y_cor;
	int id_catch;
	int walk_quant; //walkability quantile 1-high 5- low 
	rgb color <- #gray;
	aspect base {
		draw shape color: color ;
	}
}

species children skills: [moving] {
	//charctaristics
	zone my_zone;
	string gender <- flip(0.5)? "boy":"girl";
	int my_social_status; //4 social levels 1-richest 4-poorest based on AB, C1,C2,DE
	float my_activeness  <- max(0.3,gauss ({1, 0.3})) ; //distribution of tendency to be active (A)
	float outplay <- max(0,gauss ({1, 0.3})); //distribution of preference to be outdoor (O)
    float my_crime;
    int   my_simd;
	float my_simd_imp;
	int   num_friends;
	int   num_car;
	int   id_catch;
	float my_neigh_prob;
	int   dis_school;
	int   x_cor;
	int   y_cor;
	float school_walk_prob;//probability to walk to school
	
	//Physical activity
	float avg_mvpa;//average daily mvpa
	
	//float avg_mvpa_recent;//mvpa in the last two weeks
	float avg_walk;
	int   daily_od;
	int   daily_od_mvpa;
	int   mvpa_home; //home
	int   mvpa_sc ; //school
	int   mvpa_road; //walking
	float mvpa_play_field; //all types of playing fields
	int   mvpa_home_girlsarden; //home Garden
	float mvpa_park ;//Park
	float mvpa_PG;//Public garden
	float mvpa_amenity;//Amenity space
	float mvpa_shops;//shoping
	float mvpa_friends_home; //friends home
	int   mvpa_fsa;//FSA
	float per_days_sixt;	
	
	//####Variable related to agents actions
	//activities
	int dis_target;
	list<children>my_best_friends;
	list<int> act_list;
	list<int> lu_list<-list_with(27,0);//list the counts the time spent on each landuse. Land use is organised by code in the list
	string my_activity;
	int my_lu_code<-1;
	bool have_formal; //do I have formal activties today
	bool a_s_play<-false;
	int num_sport<-0;
	landuse_polygon selected_polygon;
	list<sport_activity> formal_sport_act;
	sport_activity today_sport;
	list<int> list_mvpa;
	list<int> list_lu_mvpa<-list_with(27,0);
	int tot_mvpa<-0;//the mvpa during the day-accumulates during the day
	float my_mvpa<-0.0;//the current probability for mvpa- based on the activity
	point target;
	building my_home;
	schools my_school;
	children goto_friend;////the friend to visit
	list<children> host_friends;//the friends that are hosted 
	bool meeting_friends<-false;
	float meet_hour;
	bool with_friends<-false;//when the meeting take place=true 
	path school_route;
	list<landuse_polygon> after_sc_poly;
	list<landuse_polygon> neigh_poly;
	map<landuse_polygon,int> neigh_map;
	map<landuse_polygon,int> after_sc_map;
	list<food_drink> list_food_drink;
	private_garden my_garden;
	path my_path;
	string purpose; //to determine what reflex the agent will implement
	int duration;
	int trans_mode<-0;
	float my_speed;
	bool return_home<-false;
	bool goto_school<-false;
	
	aspect default {
		if target!=nil and trans_mode=2{draw  square(12)  color:#black;}
		else {draw circle(8) border:#black color:#yellow;}
		if (school_route!=nil and show_school_routes){
			draw(school_route.shape+10) color:#magenta;		
		}
		if my_activity="Neigh play" and target=nil{draw circle(8) border:#black color:#cyan;}
	    if my_activity="Planned sport" and target=nil{draw circle(8) border:#black color:#blue;}
	}
	
	action collect_mvpa{
		mvpa_home<-int(list_lu_mvpa[1]/(days-1)) ; //home
		mvpa_sc<-int(list_lu_mvpa[20]/(days-1))  ; //school
		mvpa_road<- int(list_lu_mvpa[23]/(days-1)) ; //walking
		mvpa_play_field<- (list_lu_mvpa[15]+list_lu_mvpa[21]+list_lu_mvpa[14])/(days-1) ; //playing fields
		mvpa_home_girlsarden<-int(list_lu_mvpa[17]/(days-1)) ; //home Garden
		mvpa_park<-list_lu_mvpa[18]/(days-1)  ;//Park
		mvpa_PG<-list_lu_mvpa[3]/(days-1)  ;//Public garden
		mvpa_amenity<-list_lu_mvpa[2]/(days-1) ;//Amenity space
		mvpa_shops<-list_lu_mvpa[7]/(days-1) ;//shoping
		mvpa_friends_home<-list_lu_mvpa[24]/(days-1) ; //friends home
		mvpa_fsa<-int(list_lu_mvpa[26]/(days-1)) ;//FSA
		
	}
	
	action show_myself{
		color<-#black;
		ask neigh_poly{
			color<-#cyan;
			write lu_name+" "+ self distance_to myself;
		}
	}
	
	action show_route_sc{
		draw(school_route.shape+10) color:#magenta;	
	}
	
	
	reflex go_to_school when: current_hour=8.0 {
		purpose<-'go_school';
		target<-my_school.location;
		do transport_mode(false);
	}
	

	action transport_mode(bool return_same_mode){
		if return_same_mode=false{
			path my_route<-path_between (the_graph, location, target);
			dis_target<-int(my_route.edges sum_of (each.perimeter));
			float walk_prob;
			if purpose='go_school'{
				walk_prob<-travel_mode="active_school" or travel_mode="walk_all"?1.0:school_walk_prob;
				  //walk_prob<-dis_school<=1500?1:school_walk_prob; //walking to school scenario and walk all
			}
			else {
				if travel_mode="walk_all"{walk_prob<-1.0;}
				else{walk_prob<-num_car=0 or dis_target<300? 1: 0.3 *0.9^(my_home.walk_quant-1)+0.2*0.8^num_car+0.5*0.7^((dis_target/300)-1) ;	}
				//walk_prob<-num_car=0 or dis_target<1500? 1: 0.3 *0.9^(my_home.walk_quant-1)+0.2*0.8^num_car+0.5*0.7^((dis_target/300)-1) ; //for scenario walk all dis<1500	
			}	
	
			trans_mode<- flip(walk_prob)? 1:2;//prob for: walk=1, car=2	
		}
		my_speed<-trans_mode=1? 1.2:5; 
		return_same_mode<-false;	
	}
	
	reflex move_to_target when:target!=nil{
		
		do goto on:the_graph target:target speed:my_speed; 
		
		if  trans_mode=1 {
			if flip(mvpa_walk){ 
				tot_mvpa<- tot_mvpa+1; //updating MVPA when walking
				list_lu_mvpa[23]<-list_lu_mvpa[23]+1; 	
			} 
			
			lu_list[23]<-lu_list[23]+1; //updating walking in list
				
		}
		if trans_mode=2{
			lu_list[25]<-lu_list[25]+1; //updating car in list
			
		}
		//do report_which_road;
		
		if location=target and purpose='go_school'{
			my_activity<-"School";
			lu_list[20]<-lu_list[20]+60*6;
			int PE<-my_school.pe_day=week_day?1:0;
			float social_inf<-(1-imp_f)*my_activeness+imp_f*my_best_friends mean_of(each.my_activeness);
	 		int tmp_mvpa;
	 		if gender= 'boy'{
	 			tmp_mvpa<- int(mvpa_school*(320-SC_inter)+social_inf*(40*mvpa_recess_boys+rnd(1,15)*mvpa_arrival_boys+PE*60*mvpa_pe_boys+ mvpa_pe_boys*SC_inter));//MVPA for two break-time, during class and for arraivel	
	 		}
	 		else {
	 		    tmp_mvpa<- int(mvpa_school*(320-SC_inter)+ social_inf*(40*mvpa_recess_girls+rnd(1,15)*mvpa_arrival_girls+PE*60*mvpa_pe_girls+mvpa_pe_girls*SC_inter));//MVPA for two break-time, during class and for arraivel	
	 		}
	 		tot_mvpa<-tot_mvpa +tmp_mvpa; 
	 		list_lu_mvpa[20]<-list_lu_mvpa[20]+tmp_mvpa;	
			my_lu_code<-20;
			target<-nil;
			purpose<-'stay_school';
			location<-any_location_in(my_school);
			
			
			
			
		}
		if location=target and purpose='go_activity' {
			location<-selected_polygon!=nil? any_location_in(selected_polygon):target.location;
			target<-nil;
			if selected_polygon!=nil{
				selected_polygon.count_visits<-selected_polygon.count_visits+1;	
			}		
			purpose<-'stay_activity'; //for activity which is friends meeting the parameter is false and true otherwise
						
		}
		if location=target and purpose='go_meet' {
			location<-selected_polygon!=nil? any_location_in(selected_polygon):target.location;
			target<-nil;
			if selected_polygon!=nil{
				selected_polygon.count_visits<-selected_polygon.count_visits+1;	
			}		
			purpose<-'stay_meet'; //the agent will invoke the meeting reflex
						
		}
		if location=target and purpose='go_home'{
			target<-nil;
			purpose<-'stay_home';
			location<-any_location_in(my_home);
			
		}	
	}
	
	
	
	reflex school_time when:purpose='stay_school'{
		//end of school
	 	if current_hour>=15.0{
	 			float prob<-trans_mode=2? my_simd_imp*outplay*a_s/3:my_simd_imp*outplay*a_s; //incase the child is returning by car the likelyhood to participate decreases
	 			if have_formal and trans_mode=1{prob<-today_sport.hour-15.0>1?my_simd_imp*outplay*a_s:my_simd_imp*outplay*a_s/3; } //in case the FSA start is in one hour the likelyhood to stop decrease
	 			if flip(prob)    {
	 				do transport_mode(true);
	 				purpose<-'go_activity';
	 				a_s_play<-true;
	 				do select_activity_polygon;	
	 			}
	 			else{
	 				do transport_mode(true);
	 				do go_home;			
	 				
	 			}			
	 	}
	 	
	 					 		
	}
	
	
	reflex stay_in_activity when:purpose='stay_activity' {
		lu_list[my_lu_code]<-lu_list[my_lu_code]+1;
		duration<-duration-1;
		if flip(my_mvpa){
			tot_mvpa<-tot_mvpa+1;	
			list_lu_mvpa[my_lu_code]<-list_lu_mvpa[my_lu_code]+1;
		}
		if duration<=0 {
			selected_polygon<-nil;
				if my_lu_code=26 {have_formal<-false;}
				do go_home;
				do transport_mode(true);//true=returinig with the same transport mode
			}	
		if current_hour=20.5{
			do go_home;
			do transport_mode(true);
		}
	}
	

	
	action go_home{
		purpose<-'go_home';
		target<- my_home.location;
		my_activity<-"home";
		}	
		

	action select_activity_polygon{		
				if length(after_sc_poly)>0{
					float min_visits_poly<-after_sc_poly min_of (each.visits_per_day);
					float range_visit_poly<-after_sc_poly max_of (each.visits_per_day)-min_visits;
					ask after_sc_poly{
						added_dis<-myself.after_sc_map[self];
						float norm_dis<-0.5^((added_dis/500));//added_dis<300? 1:
						float norm_visits<-range_visit_poly=0? 0:(visits_per_day-min_visits_poly)/range_visit_poly; 
						float area_inc<-area>10000?1:0.0;//(area>2500?0.8:0.5); 
						rank<-0.6*norm_dis + 0.2*norm_visits+0.2*area_inc; // calculate the attractivity of the polygon
					}
					after_sc_poly<- (reverse(after_sc_poly sort_by(each.rank))); 
					do select_by_prob(after_sc_poly);				
					}
				else{
					do transport_mode(true);
					do go_home;
				}		
	}
	

	action select_by_prob(list<landuse_polygon> act_poly){ 
		int size_list<-length(act_poly);
		float sum_rank<-act_poly sum_of (each.rank);
		int i<-0;
		bool found<-false;
		loop while:found=false{
			selected_polygon<-act_poly[i];
			if selected_polygon.rank/sum_rank <rnd(0.0,1){
				i<-i+1=(size_list-1)? 0:(i+1);
			}
			else{
				found<-true;
			}
		}
		count_a_s<-count_a_s+1;
		do act_details(90, 20,"AS play",selected_polygon.location,self.gender="boy"?selected_polygon.mvpa_prob_B:selected_polygon.mvpa_prob_G,selected_polygon.code);	//duration 80
	}
	
	action act_details(int dur_avg, int dur_SD,string act_name, point loc,float mvpa, int the_code){
		if have_formal and with_friends=false { 
			duration<- int(max(30,-1*dur_avg*ln(1-rnd(0.0,0.999)))); 
			duration<- int(min(60*(today_sport.hour-current_hour-0.5),duration)); ////the agent activity durtation is affected by the hour of the FSA
			  
		}
		else{
			duration<- int(max(30,-1*dur_avg*ln(1-rnd(0.0,0.999))));    //int(max(15,truncated_gauss([dur_avg, dur_SD])));
			duration<- min(120,duration);
		}
		my_activity<-act_name;
		target<-loc;
		if with_friends{
			if length(host_friends)>0{
				my_mvpa<-mvpa*((1-imp_f)*my_activeness+imp_f*host_friends mean_of(each.my_activeness));	
			} 
			else{
				list<children> tmp_friends<-goto_friend.host_friends where(each!=self);
				add goto_friend to:tmp_friends;
				my_mvpa<-mvpa*((1-imp_f)*my_activeness+imp_f*tmp_friends mean_of(each.my_activeness));	
			}	
		}
		else{
			my_mvpa<-mvpa*my_activeness;
		}
		my_lu_code<-the_code;
				
	}
	
	reflex stay_home_now when: purpose='stay_home'{
			lu_list[1]<-lu_list[1]+1;
			my_activity<-'home';
			float tmp_mvpa<-gender='boy'?mvpa_home_boys:mvpa_home_girls;
			if flip(tmp_mvpa*my_activeness){
					tot_mvpa<- tot_mvpa+1;//updating MVPA for staying at home
					list_lu_mvpa[1]<-list_lu_mvpa[1]+1;	
				}
						 
			if act_hours{
				if  have_formal=true and today_sport.hour=current_hour {
					do formal_sport_activity(today_sport);		
				}
		
				
			if flip(4/60) and length(act_list)>0 and meeting_friends=false and have_formal=false {	
					list<int> tmp_list<-act_list collect  (each);
					bool next_act<-true;
					int j;
					loop while:length(tmp_list)>0 and next_act=true{
						 j<-one_of(tmp_list) ;
						remove j from:tmp_list;
						next_act<- flip(try_act_prob(j))? false:true ;
					}
					if next_act=false{
						remove j from: act_list;
						do implement_act(j);		
					}	
				}		
			}
				
		}
		
		reflex meeting_activity when:purpose='stay_meet'{
			lu_list[my_lu_code]<-lu_list[my_lu_code]+1;
			duration<-duration-1;
			if flip(my_mvpa){
				tot_mvpa<-tot_mvpa+1;	//probability for mvpa varies according to the child fittness
				list_lu_mvpa[my_lu_code]<-list_lu_mvpa[my_lu_code]+1;
			}
			if duration<=0 {
				if length(host_friends)!=0{ //updating the host friend
					with_friends<-false;
					meeting_friends<-false;	
					host_friends<-[];
					if my_lu_code=24{
						purpose<-'stay_home';//the host agent invoke the stay_home reflex
					}
					else{
						do go_home;
					 	do transport_mode(true);
					}
				}
				else{ //updating the other friends
					selected_polygon<-nil;
					with_friends<-false;
					meeting_friends<-false;
					goto_friend<-[];
					do go_home;
					do transport_mode(true);//true=returinig with the same transport mode	
				}
			
			}		
		}
		
		reflex host_meeting_friends when:length(host_friends)!=0 and current_hour=meet_hour {
			do friends_meeting;	
		}
		
		float try_act_prob(int act){//shoping
			if act=1{
				float fq<-s_a;//freqency of shoping
				return 1-(1-fq)^(1/12);	
			}
			if act=2{//neigh play
				int nm_play<-length(children where(each.my_activity="Neigh play" and each distance_to self<=300));
				float k<-nm_play>2?min(1.0,imp_kids*nm_play):0;
				//write ""+nm_play+": prob " + k ;
				float fq<-min(1,my_neigh_prob*(1+k)); // agent's prob to play in neigh effected by other children playing in the neigh 
				return 1-(1-fq)^(1/12);	//probability per selection
				
			}
			if act=3{//garden
				float fq<-g_a;//freqency of going to the garden
				return 1-(1-fq)^(1/12);		
		}
	}
		action implement_act(int i){
			if i=1{count_s_a<-count_s_a+1; do shoping;}
			if i=2 {count_n_p<-count_n_p+1;my_zone.neigh_play<-my_zone.neigh_play+1; do neigh;}
			if i=3 {count_g_a<-count_g_a+1; do garden;}
		}
		
		
		action formal_sport_activity(sport_activity the_activity){
			purpose<-'go_activity';
			count_fsa<-count_fsa+1;
			selected_polygon<-the_activity.act_poly;
			duration<-the_activity.time;
			my_activity<-"Planned sport";
			target<-selected_polygon.location;
			my_mvpa<-the_activity.mvpa*my_activeness;
			my_lu_code<-the_activity.code; 	
			do transport_mode(false);	
		}
		
		action shoping{
				purpose<-'go_activity';	
				float sum_exp_dens<-list_food_drink sum_of (1-exp(-0.3*each.density));
				int size_list<-length(list_food_drink);
				food_drink my_shop;
				if sum_exp_dens=0.0{
					my_shop<-one_of(list_food_drink);
				}
				else{
					int i<-0;
					bool found<-false;
					loop while:found=false{
						my_shop<-list_food_drink[i];
						if (1-exp(-0.3*my_shop.density))/sum_exp_dens <rnd(0.0,1){
							i<-(i+1=size_list-1)? 0:(i+1);
							}
						else{
							found<-true;
							}
						}
					}
				
				do act_details(30, 20,"Shoping", my_shop.location,mvpa_shop,7);
				do transport_mode(false);		
					
		}
		
		
		action neigh{
			purpose<-'go_activity';
			ask neigh_poly{
					dis_child<-myself.neigh_map[self];
					//dis_child<-dis_child<=300?300:dis_child;
					child_count<-length(children inside(self));	//number of others playing outside
					float c<-child_count>0? exp(-1/(child_count*0.7)):0;   
					float d<-exp(-dis_child/700);     
					float area_inc<-area>10000?1:0.0;
					rank<-0.6*d+0.2*c+0.2*area_inc;	
				}
			neigh_poly<- (reverse(neigh_poly sort_by(each.rank))); 
			int size_list<-length(neigh_poly);
			float sum<-neigh_poly sum_of (each.rank);
			if sum=0.0{
				selected_polygon<-one_of(neigh_poly);
			}
			else{
				int i<-0;
				bool found<-false;
				loop while:found=false{
					selected_polygon<-neigh_poly[i];
					if selected_polygon.rank/sum <rnd(0.0,1){
						i<-i+1=(size_list-1)? 0:(i+1);
					}
					else{
						found<-true;
					}
				}
			}
			trans_mode<-1;
			do transport_mode(true);
			do act_details(90, 30,"Neigh play", selected_polygon.location,self.gender="boy"?selected_polygon.mvpa_prob_B:selected_polygon.mvpa_prob_G,selected_polygon.code);				
					 
		}
		
		action friends_meeting { 
			float g<- mean(host_friends collect (each.outplay)+self.outplay); //joint basic probability of friends to play outdoors
			float fq<-min(1,g*f_o*my_simd_imp);//the probability to play outdoors with impact of neigh and crime
			if flip(fq){ //average of the tendencey of all friends to go out* probability of freinds to goout(f_o)
				count_friends_out<-count_friends_out+1;
				with_friends<-true;
				do neigh;// the hosting friend select the landuse
				purpose<-'go_meet';
				ask host_friends{
					count_friends_out<-count_friends_out+1;
					purpose<-'go_meet';
					with_friends<-true;
					selected_polygon<-goto_friend.selected_polygon;	
					do act_details(90, 30,"Neigh play", selected_polygon.location,self.gender="boy"?selected_polygon.mvpa_prob_B:selected_polygon.mvpa_prob_G,selected_polygon.code);
					duration<-goto_friend.duration;//keeping the same duration for all friends meeting
					do transport_mode(false);
				}		
			}
			else{
				with_friends<-true;
				purpose<-'stay_meet';//the host stay home for the meeting
				count_friends_in<-count_friends_in+1;
				duration<- int(max(30,-1*70*ln(1-rnd(0.0,0.9999))));    
				duration<-min(120,duration);//the host set the duration of the meeting
				my_activity<-'Host friends'	;
				my_lu_code<-24;
				float tmp_mvpa<-gender="boy"?mvpa_friends_in_boys:mvpa_friends_in_girls;
				my_mvpa<-tmp_mvpa*((1-imp_f)*my_activeness+imp_f*host_friends mean_of(each.my_activeness));	
				ask host_friends{
					count_friends_in<-count_friends_in+1;
					purpose<-'go_meet';
					with_friends<-true;
					do act_details(90, 30,"friends' home",goto_friend.my_home.location,gender="boy"?mvpa_friends_in_boys:mvpa_friends_in_girls,24);	
					duration<-goto_friend.duration; //keeping the same duration for all friends meeting
					do transport_mode(false);	
				}
						
			}
			
					
		}
		
		action garden{
				purpose<-'go_activity';
				do act_details(20, 10,"Garden", my_garden.location,0.1,my_garden.code);	
				trans_mode<-1;
				do transport_mode(true);					
		}					
	}


experiment Simulation type: gui until:days=60 {
	parameter "Geography cover" var:scale;
	parameter "Type of optimizer" var: optimizer_type ;
	parameter "Show school routes" var:show_school_routes;
	//parameter "Write stats" var:write_stat;
	parameter "Show zones" var:show_zones;
	parameter "Assign formal sport" var:include_fsa;
	parameter "Prob meet friends" var:f_m category:'Activities';       //prob to meet a friend (0.1)
	parameter "Prob play outdoor after school" var: a_s category:'Activities'; //prob for after school activity on the route home (0.3)
	parameter "Prob play outdoor neigh" var:n_p category:'Activities'; //prob playing at the neighborhood 0.3
	parameter "Prob meeting outdoor" var:f_o category:'Activities'; //prob of friends to goout
	parameter "Shoping" var: s_a category:'Activities';//prob shopping 0.1
	parameter "Play in garden" var:g_a category:'Activities';//prob garden 0.2
	parameter "Impact- presence of others outdoor" var:imp_kids category:'Impacts';//impact of others palying in area
	parameter "Adaptation- agents' tendency to peers" var:imp_f category:'Impacts';
	parameter "School intervention, PE min/day" var:SC_inter category:'Interventions';//duration of extra PA activity in school
	parameter "Travel mode" var:travel_mode category:'Travel';//usual, walk_school,walk_all
	
	output {		
		display Landuse_display {
			species landuse_polygon aspect:base;
			species road aspect: default refresh: false;
			species building aspect: base refresh:false;
			species schools aspect:base refresh:false;
			species private_garden aspect:base;
			species food_drink aspect:default;
			species children aspect: default refresh:true;
			species zone aspect: default;
		}
		/* 
		monitor "Time" value:with_precision(current_hour,1) color:#black ;
		monitor "Days from start" value:days;
		monitor "Day of the week" value:week_day;
		monitor "Playing in neighbourhood, %" value:int(100*count_n_p/nb_agents);
		monitor "Playing in garden, %" value:int(100*count_g_a/nb_agents);
		monitor "Meeting a friend, %" value:(100*length(children where(each.meeting_friends))/nb_agents) with_precision 0;
		monitor "After-school activity, %" value: int(100*count_a_s/nb_agents);
		monitor "Shopping, %" value: int(100*count_s_a/nb_agents);
		monitor "Formal sport, %" value: int(100*length(children where(each.have_formal))/nb_agents);
		monitor "Walking, min" value: int(children sum_of(each.lu_list[23])/(days*nb_agents));
		monitor "Car, min" value: int(children sum_of(each.lu_list[25])/(days*nb_agents));
		monitor "MVPA, all" value: mvpa_avg with_precision 1;
		monitor "SD MVPA" value: mvpa_std with_precision 1;
		monitor "MVPA boys" value: children where(each.gender="boy") mean_of (each.avg_mvpa) with_precision 1;
		monitor "MVPA girls" value: children where(each.gender="girl") mean_of (each.avg_mvpa) with_precision 1;
		monitor "zone avg mvpa" value: int(zone mean_of(each.zone_mvpa));
		monitor "zone SD mvpa" value: int(zone variance_of(each.zone_mvpa)^0.5);
		monitor "% <=60 MVPA" value:int(100*length(children where(each.avg_mvpa<=60))/nb_agents );
		monitor "% walking" value: per_walking;
		*/
	}
}
