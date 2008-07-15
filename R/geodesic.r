# Interpolates between two frames, using geodesic path, as outlined in
# http:#www-stat.wharton.upenn.edu/~buja/PAPERS/paper-dyn-proj-algs.pdf and
# http:#www-stat.wharton.upenn.edu/~buja/PAPERS/paper-dyn-proj-math.pdf
# 
# We follow the notation outlined in this paper.
# 
#   * p = dimension of data
#   * d = target dimension
#   * F = frame, an orthonormal p x d matrix
#   * Fa = starting frame, Fz = target frame
#   * ds = dim(span(Fa, Fz)), dI = dim(span(Fa) n span(Fz))
#   * Fa'Fz = Va lamda  Vz' (svd)
#   * Ga = Fa Va, Gz = Fz Vz
#   * tau = principle angles
# 
# Currently only works for d = {1, 2}.
geodesic <- function(Fa, Fz, epsilon = 1e-6) {
  # if (Fa.equivalent(Fz)) return();

  # Compute the SVD: Fa'Fz = Va lambda Vz' --------------------------------
  sv <- svd(t(Fa) %*% Fz)

  # R returns this from smallest to largest -------------------------------
  nc <- ncol(Fa)
  lambda <- sv$d[nc:1]
  Va <- sv$u[, nc:1]
  Vz <- sv$v[, nc:1]

  # Compute frames of principle directions (planes) ------------------------
  Ga <- Fa %*% Va
  Gz <- Fz %*% Vz
  
  # Form an orthogonal coordinate transformation --------------------------
  Ga <- orthonormalise(Ga)
  Gz <- orthonormalise(Gz)
  Gz <- orthonormalise_by(Gz, Ga)

  # Compute and check principal angles -----------------------
  tau <- acos(lambda)
  Gz[, tau < epsilon] <- Ga[, tau < epsilon]
  tau[tau < epsilon] <- 0
  
  list(Va = Va, Ga = Ga, Gz = Gz, tau = tau)
}
  
step_fraction <- function(interp, fraction) {
  # Interpolate between starting and end planes
  #  - multiply col-wise by angles
  G <- t(
    t(interp$Ga) * cos(fraction * interp$tau) + 
    t(interp$Gz) * sin(fraction * interp$tau)
  )

  # rotate plane to match frame Fa
  orthonormalise(G %*% t(interp$Va))
}

step_angle <- function(interp, angle) {
  step_fraction(interp, angle / sqrt(sum(interp$tau^2)))
}

geodesic_path <- function(new_target_f) { # new_target_f is the basis generator fn
  function(previous) {    
    frame <- new_target_f(previous)
    interpolator <- geodesic(previous, frame)
    dist <- sqrt(sum(interpolator$tau ^ 2))

    list(
      frame = frame,
      interpolate = function(angle) step_fraction(interpolator, angle),
      dist = dist,
       tau = interpolator$tau
    )
  }
}
