library(ChinSimi)
library(stringdist)
indfun = function(indicator1,indicator2) factor((-1)^(indicator1+indicator2) * sign(indicator1+indicator2),levels=-1:1)
lprocess = function(list,fun,compinds,...){
  biginds = which(sapply(list,length)>1)
  singles = which(!(compinds[,1] %in% biginds | compinds[,2] %in% biginds))
  if(length(singles)==nrow(compinds)){
    return(fun(unlist(list[compinds[singles,1]]),
               unlist(list[compinds[singles,2]]),...))
  }
  multis = (1:nrow(compinds))[-singles]
  res = vector(length = nrow(compinds))
  res[singles] = fun(unlist(list[compinds[singles,1]]),
                     unlist(list[compinds[singles,2]]),...)
  
  res[multis] = sapply(multis,function(i){
    temp = expand.grid(list[compinds[i,1]][[1]],list[compinds[i,2]][[1]],
                       stringsAsFactors = F)
    max(fun(temp[,1],temp[,2],...))
  })
  res
}

transparser = function(names,model = NULL, varnames = NULL,reftable = NULL){
  
  if(any(class(model) == 'xgb.Booster')) varnames = model$feature_names
  if(any(class(model) %in% c('glm','lm'))) varnames = names(coef(model))[-1]
  
  trans = unique(sapply(strsplit(gsub('min|max|diff','',varnames), '_'),'[[',1))
  sub = regmatches(trans,gregexpr('[fg][12]',trans)); sub[sapply(sub,length)==0] = ' '
  sub = unlist(sub)
  trans_ = gsub('[fg][12]','',trans)
  if(!is.null(reftable)){
    env = sys.frame(sys.parent(2))
    defvars = ls(envir = env)
    if(!('f1table' %in% defvars)){
      f1table = name_freq_table(reftable,1,1)
      assign('f1table', f1table, pos = env)
    }
      
    if(!('f2table' %in% defvars)){
      f2table = name_freq_table(reftable,1,2)
      assign('f2table', f2table, pos = env)
    } 
      
    if(!('g1table' %in% defvars)) {
      g1table = name_freq_table(reftable,2,1e3)
      assign('g1table', g1table, pos = env)
    } 
      
    if(!('g2table' %in% defvars)) {
      g2table = name_freq_table(reftable,3,1e3)
      assign('g2table', g2table, pos = env)
    } 
      
  }
  fun = list(hanzi = function(x,...) x,
               py = function(x,...) ChinSimi::ChStr2py(x,tones = T),
               wb = function(x,...) ChinSimi::ChStr2wb(x),
               fc = function(x,...) ChinSimi::ChStr2fc(x),
               rad = function(x,...) ChinSimi::ChStr2rad(x),
               radstr = function(x,...) ChinSimi::ChStr2rad(x,structure = T),
               #rad1 = function(x) ChStr2rad(x),
               #radall = function(x) ChStr2rad(x,full = T),
               #str1 = function(x) ChStr2struct(x),
               #strall = function(x) ChStr2struct(x,full = T),
               #char = function(x) nchar(x),
               han = function(x,...) ChinSimi::hancheck(x),
               nambig = function(x, ...) ChinSimi::ambig_count(x),
               freq = function(x, sub){
                 tab = get(paste0(sub,'table'),envir = env) #note, requires definitions of, e.g. g1table, for each substring
                 #st = switch(sub,f1 = 1, f2 = 1, g1 = 2, g2 = 3)
                 #en = switch(sub,f1 = 1, f2 = 2, g1 = 9999, g2 = 9999)
                 name_freq(x,tab,1,999)
               })
  subst = list(' ' = function(x) x,
               'f1' = function(x) substr(x,1,1),
               'f2' = function(x) substr(x,1,2),
               'g1' = function(x) substr(x,2,nchar(x)),
               'g2' = function(x) substr(x,3,nchar(x)))
  res = lapply(1:length(trans),function(i){
    vn = trans_[i]
    subb = sub[i]
    fn = fun[[vn]]
    
    fn(subst[[subb]](names),subb)
  })
  names(res) = trans
  res
}
expand.grid.jc <- function(seq1,seq2) {
  cbind(Var1 = rep.int(seq1, length(seq2)), 
        Var2 = rep.int(seq2, rep.int(length(seq1),length(seq2))))
}
compparser = function(tlist1, tlist2, model = NULL, varnames = NULL,nthread = parallel::detectCores()-1){
  if(any(class(model) == 'xgb.Booster')) varnames = model$feature_names
  if(any(class(model) %in% c('glm','lm'))) varnames = names(coef(model))[-1]
  
  varnames = unique(gsub('_i(.)*','_i',varnames))
  trans = sapply(strsplit(gsub('min|max|diff','',varnames), '_'),'[[',1)
  compfun = sapply(strsplit(varnames, '_'),'[',2)
  qs = regmatches(compfun,gregexpr('[0-9]', compfun))
  qs[sapply(qs,length)==0] = 1; qs = as.integer(unlist(qs))
  compfun = gsub('[0-9]','',compfun)
  #compfun[is.na(compfun)] = unlist(regmatches(varnames[is.na(compfun)],gregexpr('min|max|diff',varnames[is.na(compfun)])))
  
  cfun = list(e = function(x1,x2,...) as.numeric(sim_func(x1,x2,nthread = nthread)),
              cos = function(x1,x2,q,...) as.numeric(sim_func(x1,x2,method='cosine',
                                                                  q=q,
                                                                  nthread = nthread)),
              i = function(x1,x2,...){
                indfun(x1,x2)
              },
              c = function(x1, x2, ...){
                x1 + x2
              },
              lcs = function(x1,x2,...) as.numeric(sim_func(x1,x2,method='lcs',nthread = nthread)),
              f = function(x1,x2, ...){
                res = x1
                #checkinds = which(!is.na(res))
                
                names1 = names(x1)
                names2 = names(x2)
                
                res[which(names1 != names2)] = NA
                res
              })
  
  res = lapply(1:length(trans), function(i){
    Q = qs[i]
    cf = cfun[[compfun[i]]]
    tr = trans[i]
    x1 = tlist1[[tr]]
    x2 = tlist2[[tr]]
    cf(x1,x2,q=Q)
    
  })
  names(res) = varnames
  res = as.data.frame(res,row.names = 1:length(res[[1]]))
  return(data.frame(model.matrix.lm(~.+0,res,na.action = 'na.pass')))
}

compparser2 = function(tlist1, tlist2, model = NULL, varnames = NULL,nthread = 1){#this version automatically works with combinations
  #if(is.null(model) && length(varnames)>1)
  #  stop('If more than one variable name is provided, a model object must be provided to specify how multiple variables are to be combined for prediction')
  
  if(any(class(model) == 'xgb.Booster')) varnames = model$feature_names
  if(any(class(model) %in% c('glm','lm'))) varnames = names(coef(model))[-1]
  
  varnames = unique(gsub('_i(.)*','_i',varnames))
  trans = sapply(strsplit(gsub('min|max|diff','',varnames), '_'),'[[',1)
  compfun = sapply(strsplit(varnames, '_'),'[',2)
  qs = regmatches(compfun,gregexpr('[0-9]', compfun))
  qs[sapply(qs,length)==0] = 1; qs = as.integer(unlist(qs))
  compfun = gsub('[0-9]','',compfun)
  #compfun[is.na(compfun)] = unlist(regmatches(varnames[is.na(compfun)],gregexpr('min|max|diff',varnames[is.na(compfun)])))
  if(missing(tlist2)){
    #mat = matrix(0,nrow = length(tlist1[[1]]),ncol = length(tlist1[[1]]))
    comboinds = RcppAlgos::comboGeneral(seq_along(tlist1[[1]]),2)
    cfun = list(e = function(x1,...){
      res = sim_func_mat(x1,nthread = nthread)
      res[lower.tri(res)]
    } ,
                cos = function(x1,q,...){
                  res = sim_func_mat(x1,method='cosine',q=q,nthread = nthread)
                  res[lower.tri(res)]
                } ,
                i = function(x1,...){
                         indfun(x1[comboinds[,1]],x1[comboinds[,2]])
                         },
                c = function(x1, ...){
                  x1[comboinds[,1]] + x1[comboinds[,2]]
                       },
                lcs = function(x1,...){
                  res = sim_func_mat(x1,method='lcs',nthread =nthread)
                  res[lower.tri(res)]
                } ,
                f = function(x1, ...){
                             res = x1[comboinds[,1]]; res[names(x1)[comboinds[,1]]!=
                                                            names(x1)[comboinds[,2]]] = NA
                             res
                           })
    
    res = lapply(1:length(trans), function(i){
      Q = qs[i]
      cf = cfun[[compfun[i]]]
      tr = trans[i]
      x1 = tlist1[[tr]]
      cf(x1,q=Q)
    })
    names(res) = varnames
    res = as.data.frame(res,row.names = 1:length(res[[1]]))
    return(data.frame(model.matrix.lm(~.+0,res,na.action = 'na.pass')))
  }
  comboinds = expand.grid.jc(seq_along(tlist1[[1]]),seq_along(tlist2[[1]]))
  
  cfun = list(e = function(x1,x2,...) as.numeric(sim_func_mat(x1,x2,nthread = nthread)),
              cos = function(x1,x2,q,...) as.numeric(sim_func_mat(x1,x2,method='cosine',
                                                                  q=q,
                                                                  nthread = nthread)),
              i = function(x1,x2,...){
                           combo = expand.grid.jc(x1,x2)
                           indfun(x1[comboinds[,1]],x2[comboinds[,2]])
                         },
              c = function(x1, x2, ...){
                           x1[comboinds[,1]] + x2[comboinds[,2]]
                         },
              lcs = function(x1,x2,...) as.numeric(sim_func_mat(x1,x2,method='lcs',nthread = nthread)),
              f = function(x1,x2, ...){
                           res = x1[comboinds[,1]];
                           #checkinds = which(!is.na(res))
                           
                           names1 = names(x1)[comboinds[,1]]
                           names2 = names(x2)[comboinds[,2]]
                           
                           
                           res[which(names1 != names2)] = NA
                           res
                         })
  
  res = lapply(1:length(trans), function(i){
    Q = qs[i]
    cf = cfun[[compfun[i]]]
    tr = trans[i]
    x1 = tlist1[[tr]]
    x2 = tlist2[[tr]]
    cf(x1,x2,q=Q)
    
    })
  names(res) = varnames
  res = as.data.frame(res,row.names = 1:length(res[[1]]))
  return(data.frame(model.matrix.lm(~.+0,res,na.action = 'na.pass')))
}

chin_strsim = function(trans1,trans2,model = NULL, varnames = NULL, calprobs = FALSE,
                       calprobs.obj = NULL,reftable = NULL,nthread = 1){
  
  if(is.null(model) && length(varnames)>1)
    stop('If more than one variable name is provided, a model object must be provided to specify how multiple variables are to be combined for prediction')
  
  if(calprobs)
    if(is.null(calprobs.obj))
      stop('If calibrating probabilities, must provide a reduced isotonic regression object')
    
  
  if(any(class(model) == 'xgb.Booster')) varnames = model$feature_names
  if(any(class(model) %in% c('glm','lm'))) varnames = names(coef(model))[-1]
  
  # if(dedupe){
  #   inds = cbind(1:length(trans1[[1]]),1:length(trans2[[1]]))
  # }else{
  #   inds = expand.grid.jc(1:length(trans1[[1]]),1:length(trans2[[1]]))
  # }
  
  if(missing(trans2)){
    in_data = compparser2(trans1,varnames = varnames,nthread = nthread)
  }else{
    in_data = compparser2(trans1,trans2,varnames = varnames,nthread = nthread)
  }
  if(ncol(in_data)>1)  
    in_data = in_data[,match(varnames,names(in_data))] #reorder columns to match model order
  
  if(is.null(model))
    pred = in_data[[1]]
  
  if(any(class(model) %in% c('glm','lm'))){
    coef = coef(model)[-1]
    pred = (as.matrix(in_data[,names(coef)]) %*% coef)[,1]
  }
  
  if(any(class(model) == 'xgb.Booster'))
    pred = predict(model,xgb.DMatrix(as.matrix(in_data)))
  
  if(calprobs)
    pred = fit.isored(calprobs.obj,pred)
  
  if(missing(trans2)){
    mat = matrix(0,nrow = length(trans1[[1]]),ncol = length(trans1[[1]]))
    mat[lower.tri(mat)] = pred
    
  }else{
    mat = matrix(pred,nrow = length(trans1[[1]]),ncol = length(trans2[[1]]))
    
  }
  return(mat)
}


expand.grid.jc <- function(seq1,seq2) {
  cbind(Var1 = rep.int(seq1, length(seq2)), 
        Var2 = rep.int(seq2, rep.int(length(seq1),length(seq2))))
}

yrblocker = function(DOB,window=1,firstchars = NULL){
  years = as.numeric(format(DOB,'%Y'))
  uyrs = sort(unique(years))
  
  yrblocks = expand.grid(uyrs,uyrs)
  yrblocks = yrblocks[abs(yrblocks[,1]-yrblocks[,2])<=window,]
  yrblocks = t(apply(yrblocks,1,sort))
  yrblocks = unique(yrblocks)
  yrblocks = lapply(1:nrow(yrblocks),function(i)unique(yrblocks[i,]))
  if(is.null(firstchars)){
    
    tab = table(years)
    
    recps = sapply(yrblocks,function(x){
      temp = as.character(x)
      temp2 = tab[temp]
      ifelse(length(temp)==1,
             (temp2^2-temp2)/2,
             prod(temp2))
    }) 
    
    yrblocks = yrblocks[recps>0]
    recps = recps[recps>0]
    print(paste(sum(recps), 'record pairs total'))
    
    return(yrblocks[order(recps,decreasing = T)])  
  }else{
    unms = sort(unique(firstchars))
    tab = table(firstchars)
    recpns = (tab^2-tab)/2
    
    unms = unms[recpns>0]
    recpns = recpns[recpns>0]
    
    nrecps = sum(recpns)
    print(paste(nrecps, 'record pairs total in name blocks'))
    
    recpys = sapply(yrblocks,function(x){
      temp = lapply(x,function(y) firstchars[years == y])
      if(prod(sapply(temp,length))==1) return(NA)
      if(length(temp)==1){
        tab = table(unlist(temp))
        comps = expand.grid(names(tab),names(tab),stringsAsFactors = F)
        comps = comps[which(!(comps[,1]==comps[,2])),]
        
        #comps = t(combn(unique(unlist(temp)),2))
        
        counts = do.call(cbind,lapply(1:2,function(i) tab[comps[,i]]))
        t(counts[,1]) %*% counts[,2]/2
      }else{
        tabs = lapply(temp,table)
        comps = expand.grid(lapply(temp,unique),stringsAsFactors = F)
        comps = comps[which(!(comps[,1]==comps[,2])),]
        
        counts = do.call(cbind,lapply(1:2,function(i) tabs[[i]][comps[,i]]))
        t(counts[,1]) %*% counts[,2]
      }
    })
    
    yrblocks = yrblocks[!is.na(recpys)]
    recpys = recpys[!is.na(recpys)]
    yrecps = sum(recpys,na.rm=T)
    print(paste(nrecps + yrecps, 'record pairs total'))
    
    nblocks = unms[order(recpns,decreasing = T)]
    
    yblocks = yrblocks[order(recpys,decreasing = T)]
    
    return(list(nblocks = nblocks, yblocks = yblocks, 
                recpns = sort(recpns,decreasing = T), recpys = sort(recpys,decreasing = T)))
  }
}

seq_apportion = function(ngrps, nrps){
  sums = rep(0,ngrps)
  assgns = nrps
  for(i in 1:length(nrps)){
    k = which.min(sums)
    assgns[i] = k 
    sums[k] = sums[k] + nrps[i]
  }
  print(paste(sums, 'record pairs assigned to node', 1:ngrps))
  assgns
}

combo_indexer = function(m,N){
  i_ = m[,1]
  j_ = m[,2]
  (i_-1) * N - (i_^2 + i_)/2 + j_
}

combo_deindexer = function(inds,N){
  a = -0.5; b_u = N - 0.5

  i = ceiling((-b_u + sqrt(b_u^2 - 4 * a * -inds))/(2*a))
  
  j = inds + N - i * (N - (i + 1)/2)
  cbind(i,j)
}

grid_deindexer = function(inds,N){
  i = (inds - 1) %% N + 1
  j = (inds-1) %/% N + 1
  cbind(i,j)
}

chunker = function(seqsize, chunksize){
  lapply(1:(seqsize %/% chunksize + 1), function(i){
    c((i-1) * chunksize + 1, pmin(i * chunksize, seqsize))
  })
}

F1curve = function(scores,truth, plot = T){
  truth_ = truth[order(scores,decreasing = T)]
  scores_ = sort(scores, decreasing = T)
  Rec = cumsum(truth_)/sum(truth)
  Prec = cumsum(truth_)/(1:length(scores_))
  F1 = 2*Rec*Prec/(Rec + Prec)
  
  idx = duplicated(scores_)
  
  if(sum(idx)>0){
    dupscores = unique(scores_[idx])
    
    dropinds = which(scores_ %in% dupscores)
    dupscores = scores_[dropinds]
    
    keepinds = c(which(dupscores[2:length(dupscores)] != dupscores[1:(length(dupscores)-1)]) + 1,max(dropinds))
    
    dropinds = dropinds[-keepinds]
    
    scores_ = scores_[-dropinds]
    F1 = F1[-dropinds]
    Rec = Rec[-dropinds]
    Prec = Prec[-dropinds]
  }
  
  res = data.frame(Score = scores_, F1 = F1,Recall = Rec, Precision = Prec, TP = Rec * sum(truth))
  res$FP = (1/Prec - 1) * res$TP
  if(plot) print(ggplot(res[sample(1:nrow(res), pmin(nrow(res), 5000)),], aes(x = Score, y = F1)) + geom_line(col = 'red', alpha = 0.5,lwd = 1))
  return(list(
    fulldata = res,
    opt.thresh = scores_[which.max(F1)],
    opt.F1 = max(F1)
  ))
}



F_adjust = function(F1curve,baseline_pi,new_pi, plot = T){
  
  #newFP = F1curve$FP * (1-new_pi)/(1-baseline_pi)
  temp = 1/F1curve$Prec - 1
  newPrec = 1/(temp * baseline_pi/new_pi * (1-new_pi)/(1-baseline_pi) + 1)
  newF1 = 2*(newPrec * F1curve$Recall)/(newPrec + F1curve$Recall)
  
  res = F1curve
  res$Prec = newPrec; res$oldF1 = res$F1; res$F1 = newF1
  opt.thresh_old = res$Score[which.max(res$oldF1)]; opt.thresh = res$Score[which.max(res$F1)]; opt.F1 = max(res$F1)
  if(plot) print(ggplot(res[sample(1:nrow(res), pmin(nrow(res), 5000)),], aes(x = Score, y = oldF1)) + geom_line(col = 'red', alpha = 0.5,lwd = 1) + 
                   geom_line(col = 'blue', aes(y = F1), alpha = 0.5, lwd = 1) + geom_vline(col = 'blue', aes(xintercept = opt.thresh)) + 
                   geom_vline(col = 'red', aes(xintercept = opt.thresh_old)))
  return(list(
    fulldata = res,
    opt.thresh = opt.thresh,
    opt.F1 = opt.F1
  ))
}


isoreg.reduce = function(isoreg){
  res=list()
  
  if(class(isoreg) == 'monoreg'){
    ord = 1:length(isoreg$x)
  } else{
    ord = isoreg$ord
  }
  
  
  res$x = isoreg$x[ord]
  res$y = isoreg$yf
  
  res$x = tapply(res$x,res$y,function(x) unique(range(x)))
  reps = lapply(res$x,length)
  res$x = unlist(res$x)
  res$y = rep(unique(res$y),reps)
  res
}

fit.isored <- function(isored, x0){
  x = isored$x
  y = isored$y
  ind = cut(x0, breaks = x, labels = FALSE, include.lowest = TRUE)
  min.x <- min(x)
  max.x <- max(x)
  ind[x0 > max.x] = length(x)
  ind[x0 < min.x] = 1
  
  slope = c(diff(y)/diff(x),0)
  val = y[ind] + (x0 - x[ind]) * slope[ind]
  val
}

Measure_AUROCE = function(probs,truth){
  ntrue = sum(truth)
  nfalse = sum(1-truth)
  
  ord = order(probs,decreasing = T)
  
  truth = truth[ord]
  probs = probs[ord]
  
  TPR = cumsum(truth)/ntrue
  FPR = cumsum(1-truth)/nfalse
  
  idx = c(diff(probs)==0,F)
  
  TPR = TPR[!idx]
  FPR = FPR[!idx]
  
  
  if(min(FPR,na.rm=T)>=ntrue/nfalse) return(0)
  if(ntrue/nfalse <= 1){
    if((ntrue/nfalse) %in% FPR){
      TPR = c(0,TPR[FPR <= ntrue/nfalse])
      FPR = c(FPR[1],FPR[FPR <= ntrue/nfalse])
      
    }else{
      interp_point = which(FPR == min(FPR[FPR>ntrue/nfalse],na.rm=T))[1]
      
      rise = TPR[interp_point] - TPR[interp_point-1]
      run = FPR[interp_point] - FPR[interp_point-1]
      dist = ntrue/nfalse - FPR[interp_point-1]
      
      TPR = c(0,TPR[1:(interp_point-1)], TPR[interp_point-1] + rise/run * dist)
      FPR = c(FPR[1],FPR[1:(interp_point-1)],ntrue/nfalse)
      
    }
  }
  widths = diff(FPR)
  rechght = pmin(TPR[1:(length(TPR)-1)],TPR[2:length(TPR)])
  trihght = abs(diff(TPR))/2
  sum(widths * (rechght + trihght), na.rm = T)/(ntrue/nfalse)
}

bcorr = function(patterns){
  L = which(colnames(patterns)=='counts')-1
  counts = patterns[,L+1]
  N = sum(counts)
  corvec = numeric(.5*(L^2-L))
  names(corvec) = apply(t(combn(colnames(patterns)[1:L],2)),1,paste0,collapse=':')
  ps = apply(patterns[,1:L],2,function(v) sum((v==2) * counts,na.rm=T)/N)
  ind = 1
  for(i in 1:(L-1))
    for(j in (i+1):L){
      p_ij = sum((patterns[,i]==2 & patterns[,j]==2) * counts,na.rm=T) / N
      corvec[ind] = (p_ij - ps[i]*ps[j])/sqrt(ps[j]*(1-ps[j])*ps[i]*(1-ps[i]))
      ind = ind + 1
    }
  corvec
}
mcorr = function(zeta,p.m,patterns){
  L = which(colnames(patterns)=='counts')-1
  counts = patterns[,L+1]
  
  counts_m = zeta * counts
  counts_u = (1-zeta) * counts
  N_m = sum(counts_m)
  N_u = sum(counts_u)
  
  corvec = numeric(.5*(L^2-L))
  names(corvec) = apply(t(combn(colnames(patterns)[1:L],2)),1,paste0,collapse=':')
  ps = apply(patterns[,1:L],2,function(v) p.m * sum((v==2) * counts_m,na.rm=T) / N_m + 
               (1-p.m) * sum((v==2) * counts_u,na.rm=T) / N_u)
  
  ind = 1
  for(i in 1:(L-1))
    for(j in (i+1):L){
      p_ij = p.m * sum((patterns[,i] & patterns[,j]) * counts_m,na.rm=T) / N_m + (1-p.m) * 
        sum((patterns[,i] & patterns[,j]) * counts_u,na.rm=T) / N_u
      corvec[ind] = (p_ij - ps[i]*ps[j])/sqrt(ps[j]*(1-ps[j])*ps[i]*(1-ps[i]))
      ind = ind + 1
    }
  corvec
}
corplot = function(fit,title=NULL){
  zeta = fit$zeta.j; p.m = fit$p.m; patterns = fit$patterns.w
  
  mcor = mcorr(zeta,p.m,patterns); bcor = bcorr(patterns)
  labs = names(bcor)
  ylim = c(min(mcor-bcor) - .25, max(mcor-bcor) + .25)
  plot(mcor-bcor, ylim = ylim, type = 'l',main = title, ylab = 'correlation error',xlab='')
  text(x=1:length(bcor), y = (mcor-bcor) + .1, labels = labs, cex = 0.8, srt = 60)
}

p_thresh_adjust = function(cal_prob, baseline_pi, new_pi){
  #solve p(M|new_pi) = p(M|old_pi) = cal_prob
  
  targ_odds = cal_prob/(1-cal_prob)
  targ_C = targ_odds / (new_pi/(1-new_pi))
  
  odds = targ_C * baseline_pi/(1-baseline_pi)
  odds/(1+odds) #adjusted probability threshold
}

F_adjust_link = function(Fcurve, flinkres, thresh.match,namecol, plot = T, aggressive = T){
  devel_p.m = 7.744855e-06
  devel_p.u = 1- devel_p.m
  
  if(aggressive){
    namecol = grep(namecol, colnames(flinkres$patterns.w))
    
    fcols = 1:length(flinkres$varnames)
    
    linked = which(flinkres$zeta.j >= thresh.match)
    pats = flinkres$patterns.w[linked,fcols]
    newpats = pats
    newpats[,namecol] = 0
    
    newpats = unique(newpats)
    
    newpats_ = unique(rbind(pats,newpats))
    newpats_ = apply(newpats_,1,paste0,collapse = '')
    
    allpats_ = apply(flinkres$patterns.w[,fcols],1,paste0,collapse = '')
    counts = flinkres$patterns.w[match(newpats_,allpats_),'counts']
    probs = flinkres$zeta.j[match(newpats_,allpats_)]
    
    app_p.m = sum(counts * probs,na.rm=T)/sum(counts)
    app_p.u = sum(counts * (1-probs), na.rm=T)/sum(counts)
  }else{
    app_p.m = flinkres$p.m
    app_p.u = flinkres$p.u
  }
  
  Fcurve$FP = Fcurve$FP * app_p.u/devel_p.u
  Fcurve$TP = Fcurve$TP * app_p.m/devel_p.m
  
  Fcurve$Recall = Fcurve$TP/max(Fcurve$TP)
  Fcurve$Precision = Fcurve$TP/(Fcurve$TP + Fcurve$FP)
  Fcurve$F1old = Fcurve$F1
  Fcurve$F1 = 2 * Fcurve$Precision * Fcurve$Recall / (Fcurve$Precision + Fcurve$Recall)
  
  opt.thresh.old = Fcurve$Score[which.max(Fcurve$F1old)]
  opt.thresh = Fcurve$Score[which.max(Fcurve$F1)]
  
  if(plot) print(ggplot(Fcurve[sample(1:nrow(Fcurve), pmin(5000,nrow(Fcurve))),], aes(x = Score, y = F1old)) + geom_line(col = 'red',lwd = 1, alpha = 0.5) + 
                   geom_line(aes(y = F1), col = 'blue', lwd = 1,alpha = 0.5) + geom_vline(col = 'red',xintercept = opt.thresh.old) + 
                   geom_vline(col = 'blue', xintercept = opt.thresh) + ylab('F1') + xlab('Classifier Score'))
  
  return(list(
    curvedat = Fcurve,
    opt.thresh = Fcurve$Score[which.max(Fcurve$F1)],
    opt.F1 = max(Fcurve$F1)
  ))
}

expit = function(x) 1/(1+exp(-x))

logit = function(x) log(x/(1-x))

ecdf_reduce = function(ecdf,resolution = 1e5, minscore = 0, maxscore = 1){
  x = seq(minscore,maxscore,length.out = resolution)
  y = ecdf(x)
  temp = list(x=x, yf = y)
  class(temp) = 'monoreg'
  isoreg.reduce(temp)
}

fit.ecdf.red = function(ecdf.red,x){
  fit.isored(ecdf.red,x)
}
 
Double_thresh_estimator = function(m_ecdf,u_ecdf,flinkres,thresh.match,namecol,cut.a = 0.95,cut.p = 0.5, linkfun = expit, 
                                   stickfun = function(x,y) x + expit(y) * (1-x), aggressive = T,start = c(3,-3)){
  
  if(aggressive){
    namecol = grep(namecol, colnames(flinkres$patterns.w))
    
    fcols = 1:length(flinkres$varnames)
    
    linked = which(flinkres$zeta.j >= thresh.match)
    pats = flinkres$patterns.w[linked,fcols]
    newpats = pats
    newpats[,namecol] = 0
    
    newpats = unique(newpats)
    
    newpats_ = unique(rbind(pats,newpats))
    newpats_ = apply(newpats_,1,paste0,collapse = '')
    
    allpats_ = apply(flinkres$patterns.w[,fcols],1,paste0,collapse = '')
    counts = flinkres$patterns.w[match(newpats_,allpats_),'counts']
    probs = flinkres$zeta.j[match(newpats_,allpats_)]
    
    app_p.m = sum(counts * probs,na.rm=T)
    app_p.u = sum(counts * (1-probs), na.rm=T)
  }else{
    app_p.m = flinkres$p.m * sum(flinkres$patterns.w[,'counts'])
    app_p.u = flinkres$p.u * sum(flinkres$patterns.w[,'counts'])
  }
 
  find_cuts = function(cuts){
    cut.2 = linkfun(cuts[2])
    cut.1 = stickfun(cut.2, cuts[1])
    
    
    (app_p.m * (1-fit.ecdf.red(m_ecdf,cut.1)) /(app_p.m * (1-fit.ecdf.red(m_ecdf,cut.1)) + 
                                               app_p.u * (1-fit.ecdf.red(u_ecdf,cut.1))) - cut.a)^2 + 
      (app_p.m * (fit.ecdf.red(m_ecdf,cut.1) - fit.ecdf.red(m_ecdf,cut.2)) / 
         (app_p.m * (fit.ecdf.red(m_ecdf,cut.1) - fit.ecdf.red(m_ecdf,cut.2)) + 
            app_p.u * (fit.ecdf.red(u_ecdf,cut.1) - fit.ecdf.red(u_ecdf,cut.2))) - cut.p)^2
  }
  
  cut = optim(start,find_cuts)$par
  cut[2] = linkfun(cut[2])
  cut[1] = stickfun(cut[2],cut[1])
  
  ratio.1 = app_p.m * (1-fit.ecdf.red(m_ecdf,cut[1])) / (app_p.m * (1-fit.ecdf.red(m_ecdf,cut[1])) + 
                                                      app_p.u * (1-fit.ecdf.red(u_ecdf,cut[1])))
  ratio.2 = app_p.m * (fit.ecdf.red(m_ecdf,cut[1]) - fit.ecdf.red(m_ecdf,cut[2])) / 
    (app_p.m * (fit.ecdf.red(m_ecdf,cut[1]) - fit.ecdf.red(m_ecdf,cut[2])) + 
       app_p.u * (fit.ecdf.red(u_ecdf,cut[1]) - fit.ecdf.red(u_ecdf,cut[2])))
  
  cat('Estimated probability of match for upper threshold is ', ratio.1,'\n')
  cat('Estimated probability of match for lower threshold is ', ratio.2,'\n')
  
  return(list(
    cut.a = cut[1],
    cut.p = cut[2]
  ))
}


ratio.plotter = function(m_ecdf,u_ecdf,p.m){
  p.u = 1-p.m
  xs = seq(min(u_ecdf$x),max(m_ecdf$x),length.out = 1e4)
  m.lh = p.m * (1-fit.ecdf.red(m_ecdf,xs))
  u.lh = p.u * (1-fit.ecdf.red(u_ecdf,xs))
  plot(xs,m.lh/(m.lh + u.lh), 'l')
}

ratio.plotter2 = function(m_ecdf,u_ecdf,p.m,score1){
  p.u = 1-p.m
  xs = seq(min(u_ecdf$x),score1,length.out = 1e4)
  m.lh = p.m * (fit.ecdf.red(m_ecdf,score1)-fit.ecdf.red(m_ecdf,xs))
  u.lh = p.u * (fit.ecdf.red(u_ecdf,score1)-fit.ecdf.red(u_ecdf,xs))
  plot(xs,m.lh/(m.lh + u.lh), 'l')
}


link.thresh = function(flinkres){
  Ntarg = flinkres$p.m * sum(flinkres$patterns.w[,'counts'])
  scounts = flinkres$patterns.w[order(flinkres$zeta.j,decreasing = T),'counts']
  sprobs = sort(flinkres$zeta.j,decreasing = T)
  sprobs[which.min(abs(cumsum(scounts) - Ntarg))]
}