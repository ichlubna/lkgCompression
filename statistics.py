import numpy as np
import dcor
nums = "0.01153846154	-0.01153846154	0.05	0.3038461538	0.6923076923	0.8576923077"
nums2 = "0.00813971061	0.02276380594	0.03046782787	0.04582006565	0.0413766573	0.02121449232"
a = np.array(nums.split(), dtype=float)
b = np.array(nums2.split(), dtype=float)
print(a)
print(b)
print(dcor.distance_correlation(a, b))
